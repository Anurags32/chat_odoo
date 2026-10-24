import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../config.dart';
import '../models/rtc_peer_session.dart';
import 'odoo_api.dart';
import 'signaling_service.dart';
import 'rtc_logger.dart';

enum CallStatus { idle, ringing, connecting, connected, ended, failed }

class RtcCallService extends ChangeNotifier {
  final OdooApi _odooApi;
  final SignalingService _signalingService;

  // Renderers
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  bool _localRendererInitialized = false;

  // Active Peer Connections mapped per remoteSessionId (Mesh WebRTC)
  final Map<int, RtcPeerSession> _peers = {};

  MediaStream? _localStream;
  MediaStream? _localScreenStream;

  CallStatus _status = CallStatus.idle;
  int _channelId = 0;
  int? _selfSessionId;

  bool _isVideo = false;
  bool _isVideoOff = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isScreenSharing = false;
  int _callDuration = 0;

  bool _isJoining = false;

  Timer? _durationTimer;
  Timer? _diagnosisTimer;
  Timer? _pingTimer;
  Timer? _statsTimer;

  // Serialized inbound queue to prevent race conditions during SDP negotiation
  Future<void> _inboundQueue = Future.value();

  CallStatus get status => _status;
  int get channelId => _channelId;
  int? get selfSessionId => _selfSessionId;
  bool get isVideo => _isVideo;
  bool get isVideoOff => _isVideoOff;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isScreenSharing => _isScreenSharing;
  int get callDuration => _callDuration;
  MediaStream? get localStream => _localStream;

  Map<int, RtcPeerSession> get peers => _peers;
  List<RtcPeerSession> get peerList => _peers.values.toList();
  RtcPeerSession? get primaryPeer => _peers.values.firstOrNull;

  String get iceConnectionState => primaryPeer?.iceConnectionState ?? 'new';
  String get peerConnectionState => primaryPeer?.peerConnectionState ?? 'new';

  RTCVideoRenderer get remoteRenderer => primaryPeer?.remoteRenderer ?? localRenderer;

  RtcCallService({
    required OdooApi odooApi,
    required SignalingService signalingService,
  }) : _odooApi = odooApi,
       _signalingService = signalingService {
    _initSignalingListeners();
  }

  void _initSignalingListeners() {
    _signalingService.onPeerNotification = _handlePeerNotification;
    _signalingService.onRtcSessionsUpdate = _handleRtcSessionsUpdate;
    _signalingService.onSessionEnded = _handleSessionEnded;
  }

  /// Initialize local video renderer
  Future<void> initLocalRenderer() async {
    if (_localRendererInitialized) return;
    try {
      await localRenderer.initialize();
      _localRendererInitialized = true;
      RtcLogger.instance.log('Local RTCVideoRenderer initialized.', tag: 'MEDIA');
    } catch (e) {
      RtcLogger.instance.log('Failed to init local renderer: $e', tag: 'MEDIA');
    }
  }

  /// Legacy helper for pages expecting initRenderers()
  Future<void> initRenderers() async {
    await initLocalRenderer();
    for (final p in _peers.values) {
      await p.initRenderer();
    }
  }

  /// Start or join a voice or video call on the given Odoo Discuss channel
  Future<bool> joinCall({
    required int channelId,
    bool isVideo = false,
    bool createOfferIfFirst = true,
  }) async {
    if (_isJoining) {
      RtcLogger.instance.log('Already in joinCall flow, ignoring duplicate invocation.', tag: 'CALL');
      return false;
    }

    _isJoining = true;
    RtcLogger.instance.resetCounters();
    RtcLogger.instance.log(
      'Starting joinCall flow on channel $channelId (isVideo: $isVideo)...',
      tag: 'CALL',
    );

    // If already in a previous call, clean up first
    if (_status != CallStatus.idle) {
      await hangUp(remoteInitiated: false, notifyRemote: false);
    }

    _channelId = channelId;
    _isVideo = isVideo;
    _isVideoOff = false;
    _status = CallStatus.connecting;
    _callDuration = 0;
    notifyListeners();

    try {
      // 1. Check microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _status = CallStatus.failed;
        RtcLogger.instance.log('Microphone permission DENIED.', tag: 'PERM');
        _isJoining = false;
        notifyListeners();
        return false;
      }

      // 2. Check camera permission if video
      if (_isVideo) {
        final camStatus = await Permission.camera.request();
        if (!camStatus.isGranted) {
          _status = CallStatus.failed;
          RtcLogger.instance.log('Camera permission DENIED.', tag: 'PERM');
          _isJoining = false;
          notifyListeners();
          return false;
        }
        await initLocalRenderer();
      }

      // 3. Connect Signaling WebSocket to channel bus
      await _signalingService.connect(channelId: channelId);

      // 4. HTTP POST /mail/rtc/channel/join_call
      final joinResult = await _odooApi.joinCall(
        channelId: channelId,
        camera: _isVideo,
      );

      if (joinResult.containsKey('error') || joinResult['sessionId'] == null) {
        RtcLogger.instance.log(
          'Failed to join call via Odoo: ${joinResult['error']}',
          tag: 'CALL',
        );
        _status = CallStatus.failed;
        _isJoining = false;
        notifyListeners();
        return false;
      }

      _selfSessionId = joinResult['sessionId'] as int;
      final odooIceServers = joinResult['iceServers'] as List? ?? [];
      final rtcSessions = joinResult['rtcSessions'] as List? ?? [];

      RtcLogger.instance.log(
        'Joined Odoo Call! selfSessionId=$_selfSessionId | iceServers=${odooIceServers.length} | activeSessions=${rtcSessions.length}',
        tag: 'CALL',
      );

      // Immediately subscribe bus to our specific RTC session channel for peer_notification routing!
      _signalingService.updateSelfSessionId(_selfSessionId!);

      // 5. Build ICE servers list with TURN fallback
      final iceServers = _buildIceServers(odooIceServers);

      // 6. Acquire local media stream (mic + optional camera)
      await _acquireLocalMedia();

      // 7. Track remote sessions in channel and initialize peer connection mesh
      final remoteSessionIds = <int>[];
      for (final s in rtcSessions) {
        if (s is Map && s['id'] != null && s['id'] != _selfSessionId) {
          remoteSessionIds.add(s['id'] as int);
        }
      }

      RtcLogger.instance.log('Discovered initial remote sessions: $remoteSessionIds', tag: 'CALL');

      // Initialize mesh connections for all existing participants
      for (final remoteId in remoteSessionIds) {
        await _getOrCreatePeer(remoteId, iceServers);
      }

      // 8. Start timers
      _startDiagnosisTimer();
      _startPingTimer();
      _startStatsTimer();

      _isJoining = false;
      notifyListeners();
      return true;
    } catch (e) {
      RtcLogger.instance.log('Exception in joinCall: $e', tag: 'CALL-ERROR');
      _status = CallStatus.failed;
      _isJoining = false;
      notifyListeners();
      return false;
    }
  }

  /// Build unified ICE servers list merging Odoo servers + STUN + TURN fallback
  List<Map<String, dynamic>> _buildIceServers(List<dynamic> fromOdoo) {
    final result = <Map<String, dynamic>>[];
    bool hasTurnServer = false;

    for (final item in fromOdoo) {
      if (item is Map) {
        final serverMap = Map<String, dynamic>.from(item);
        result.add(serverMap);
        final urls = serverMap['urls'];
        if (urls is List && urls.any((u) => u.toString().startsWith('turn:'))) {
          hasTurnServer = true;
        } else if (serverMap['url']?.toString().startsWith('turn:') == true) {
          hasTurnServer = true;
        }
      }
    }

    if (result.isEmpty) {
      result.addAll(CallConfig.stunFallback);
    }

    // Append fallback TURN if Odoo did not provide one
    if (!hasTurnServer) {
      RtcLogger.instance.log('No TURN server from Odoo. Appending fallback TURN list...', tag: 'ICE-CONFIG');
      result.addAll(CallConfig.turnFallback);
    }

    RtcLogger.instance.log('Configured ${result.length} ICE server(s) (hasTurn: $hasTurnServer).', tag: 'ICE-CONFIG');
    return result;
  }

  /// Create and configure a PeerSession for a remote participant
  Future<RtcPeerSession> _getOrCreatePeer(int remoteSessionId, [List<Map<String, dynamic>>? iceServers]) async {
    if (_peers.containsKey(remoteSessionId)) {
      return _peers[remoteSessionId]!;
    }

    final servers = iceServers ?? _buildIceServers([]);
    final config = {
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
    };

    RtcLogger.instance.log('Creating PeerConnection for session $remoteSessionId...', tag: 'WEBRTC');
    final pc = await createPeerConnection(config);

    // Polite Peer logic mirroring Odoo web: hasPriority = remoteSessionId > selfSessionId
    final hasPriority = remoteSessionId > (_selfSessionId ?? 0);

    final peer = RtcPeerSession(
      remoteSessionId: remoteSessionId,
      selfSessionId: _selfSessionId ?? 0,
      connection: pc,
      hasPriority: hasPriority,
    );

    await peer.initRenderer();
    _peers[remoteSessionId] = peer;

    // ── 1. Create Negotiated DataChannel "notifications" (id: 1) ────────────
    try {
      final dc = await pc.createDataChannel(
        'notifications',
        RTCDataChannelInit()
          ..negotiated = true
          ..id = 1,
      );
      peer.dataChannel = dc;

      dc.onDataChannelState = (state) {
        RtcLogger.instance.log('DataChannel state [$remoteSessionId]: $state', tag: 'DATA-CHANNEL');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          _sendDataChannelInfo(peer);
          _sendDataChannelMessage(peer, 'broadcast', {'sequence': peer.sequence});
        }
      };

      dc.onMessage = (msg) {
        RtcLogger.instance.log('DataChannel message from $remoteSessionId: ${msg.text}', tag: 'DATA-CHANNEL');
        _handleDataChannelMessage(peer, msg.text);
      };
    } catch (e) {
      RtcLogger.instance.log('Failed to create DataChannel for peer $remoteSessionId: $e', tag: 'DATA-CHANNEL');
    }

    // ── 2. Add 3 Transceivers in EXACT ORDER matching Odoo 18 web client ────
    // Order: [audio, camera video, screen video]
    try {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );

      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: (_isVideo && !_isVideoOff) ? TransceiverDirection.SendRecv : TransceiverDirection.RecvOnly,
        ),
      );

      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      RtcLogger.instance.log(
        'Created 3 transceivers (Audio: SendRecv, Cam: ${_isVideo ? "SendRecv" : "RecvOnly"}, Screen: RecvOnly) for $remoteSessionId',
        tag: 'WEBRTC',
      );
    } catch (e) {
      RtcLogger.instance.log('Failed to create transceivers for $remoteSessionId: $e', tag: 'WEBRTC');
    }

    // ── 3. Attach Local Tracks to Transceivers ──────────────────────────────
    await _attachLocalMediaToPeer(peer);

    // ── 4. MANDATORY LISTENERS REGISTERED BEFORE ANY setLocalDescription ─────
    pc.onIceCandidate = (candidate) {
      RtcLogger.instance.logCandidate(candidate, isLocal: true);
      _sendLocalIceCandidate(peer, candidate);
    };

    pc.onTrack = (event) async {
      RtcLogger.instance.log(
        'Remote track received from $remoteSessionId: kind=${event.track.kind}, id=${event.track.id}',
        tag: 'MEDIA',
      );
      event.track.enabled = true;

      if (peer.remoteStream == null) {
        if (event.streams.isNotEmpty) {
          peer.remoteStream = event.streams[0];
        } else {
          // Unified Plan manual stream creation
          peer.remoteStream = await createLocalMediaStream('remote_${peer.remoteSessionId}_${DateTime.now().millisecondsSinceEpoch}');
        }
      }
      peer.remoteStream!.addTrack(event.track);

      if (event.track.kind == 'video') {
        peer.remoteVideoTrack = event.track;
        peer.isCameraActive = true;
        await peer.initRenderer();
        peer.remoteRenderer.srcObject = peer.remoteStream;
        RtcLogger.instance.log('Attached remote video stream to renderer for $remoteSessionId', tag: 'MEDIA');
      } else if (event.track.kind == 'audio') {
        peer.remoteAudioTrack = event.track;
        peer.isAudioActive = true;
        try {
          await Helper.setSpeakerphoneOn(_isSpeakerOn);
        } catch (_) {}
        RtcLogger.instance.log('Attached remote audio stream for $remoteSessionId', tag: 'MEDIA');
      }
      notifyListeners();
    };

    pc.onIceConnectionState = (state) {
      peer.iceConnectionState = state.name;
      RtcLogger.instance.log('ICE [$remoteSessionId]: $state', tag: 'ICE');
      _handleIceStateChange(peer, state);
    };

    pc.onConnectionState = (state) {
      peer.peerConnectionState = state.name;
      RtcLogger.instance.log('PC [$remoteSessionId]: $state', tag: 'PC');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _status = CallStatus.connected;
        _startDurationTimer();
        notifyListeners();
      }
    };

    pc.onIceGatheringState = (state) {
      peer.iceGatheringState = state.name;
      RtcLogger.instance.log('GATHER [$remoteSessionId]: $state', tag: 'GATHER');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        RtcLogger.instance.logGatheringComplete();
      }
    };

    // ── 5. Perfect Negotiation: onRenegotiationNeeded ───────────────────────
    pc.onRenegotiationNeeded = () async {
      RtcLogger.instance.log('onRenegotiationNeeded triggered for peer $remoteSessionId', tag: 'NEGOTIATION');
      await _negotiateOffer(peer);
    };

    notifyListeners();
    return peer;
  }

  /// Create and send offer for a peer
  Future<void> _negotiateOffer(RtcPeerSession peer) async {
    if (peer.isBuildingOffer || _selfSessionId == null) return;
    peer.isBuildingOffer = true;

    try {
      final offer = await peer.connection.createOffer();
      await peer.connection.setLocalDescription(offer);
      peer.isBuildingOffer = false;

      RtcLogger.instance.log('Local offer set for ${peer.remoteSessionId} (seq ${peer.sequence}).', tag: 'SDP');

      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: [peer.remoteSessionId],
        channelId: _channelId,
        event: 'offer',
        payload: {
          'sdp': {'type': offer.type, 'sdp': offer.sdp},
          'sequence': peer.sequence++,
        },
      );
    } catch (e) {
      peer.isBuildingOffer = false;
      RtcLogger.instance.log('Failed to create/send offer for ${peer.remoteSessionId}: $e', tag: 'SDP-ERROR');
    }
  }

  /// Acquire local media tracks (mic + optional camera)
  Future<void> _acquireLocalMedia() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': _isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _isMuted = false;
      _isVideoOff = false;

      for (final t in _localStream!.getAudioTracks()) {
        t.enabled = true;
      }
      for (final t in _localStream!.getVideoTracks()) {
        t.enabled = true;
      }

      if (_isVideo) {
        await initLocalRenderer();
        localRenderer.srcObject = _localStream;
      }

      RtcLogger.instance.log('Acquired local media stream (video: $_isVideo).', tag: 'MEDIA');
    } catch (e) {
      RtcLogger.instance.log('Error acquiring local media: $e', tag: 'MEDIA');
    }
  }

  /// Safely attach local tracks to a peer's transceivers via replaceTrack
  Future<void> _attachLocalMediaToPeer(RtcPeerSession peer) async {
    if (_localStream == null) return;

    try {
      final transceivers = await peer.connection.getTransceivers();
      if (transceivers.isEmpty) return;

      // 1. Audio track (1st transceiver)
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null && transceivers.isNotEmpty) {
        audioTrack.enabled = !_isMuted;
        try {
          await transceivers[0].sender.replaceTrack(audioTrack);
          await transceivers[0].setDirection(TransceiverDirection.SendRecv);
          RtcLogger.instance.log('Attached audio track to peer ${peer.remoteSessionId}', tag: 'MEDIA');
        } catch (e) {
          RtcLogger.instance.log('Failed to attach audio track: $e', tag: 'MEDIA');
        }
      }

      // 2. Camera video track (2nd transceiver)
      if (_isVideo && transceivers.length >= 2) {
        final videoTrack = _localStream!.getVideoTracks().firstOrNull;
        if (videoTrack != null) {
          videoTrack.enabled = !_isVideoOff;
          try {
            await transceivers[1].sender.replaceTrack(videoTrack);
            await transceivers[1].setDirection(
              _isVideoOff ? TransceiverDirection.RecvOnly : TransceiverDirection.SendRecv,
            );
            RtcLogger.instance.log('Attached camera track to peer ${peer.remoteSessionId}', tag: 'MEDIA');
          } catch (e) {
            RtcLogger.instance.log('Failed to attach camera track: $e', tag: 'MEDIA');
          }
        }
      }
    } catch (e) {
      RtcLogger.instance.log('Error attaching media to peer: $e', tag: 'MEDIA');
    }
  }

  void _sendLocalIceCandidate(RtcPeerSession peer, RTCIceCandidate candidate) {
    if (_selfSessionId == null || _channelId == 0) return;

    final candMap = {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };

    _signalingService.enqueueSignal(
      senderSessionId: _selfSessionId!,
      targetSessionIds: [peer.remoteSessionId],
      channelId: _channelId,
      event: 'ice-candidate',
      payload: {'candidate': candMap},
    );
  }

  /// Handle incoming bus peer notification with serial queue
  void _handlePeerNotification(
    int senderSessionId,
    String event,
    Map<String, dynamic> payload,
    int sequence,
  ) {
    _inboundQueue = _inboundQueue.then((_) => _processPeerNotification(
      senderSessionId,
      event,
      payload,
      sequence,
    ));
  }

  Future<void> _processPeerNotification(
    int senderSessionId,
    String event,
    Map<String, dynamic> payload,
    int sequence,
  ) async {
    final peer = await _getOrCreatePeer(senderSessionId);
    peer.sequence = sequence;

    switch (event) {
      case 'offer':
        await _handleIncomingOffer(peer, payload);
        break;
      case 'answer':
        await _handleIncomingAnswer(peer, payload);
        break;
      case 'ice-candidate':
        await _handleIncomingCandidate(peer, payload);
        break;
      case 'trackChange':
        _handleIncomingTrackChange(peer, payload);
        break;
      case 'disconnect':
        RtcLogger.instance.log('Peer $senderSessionId disconnected.', tag: 'PEER');
        await _removePeer(senderSessionId);
        break;
    }
  }

  /// Handle incoming offer with Polite Peer collision resolution
  Future<void> _handleIncomingOffer(RtcPeerSession peer, Map<String, dynamic> payload) async {
    final sdpData = payload['sdp'];
    if (sdpData is! Map) return;

    final sdpStr = sdpData['sdp'] as String? ?? '';
    final typeStr = sdpData['type'] as String? ?? 'offer';

    RtcLogger.instance.log('Processing incoming offer from session ${peer.remoteSessionId}...', tag: 'SDP');

    // Detect offer collision
    final signalingState = peer.connection.signalingState;
    final isStable = signalingState == RTCSignalingState.RTCSignalingStateStable || peer.isBuildingAnswer;
    final hasCollision = !isStable || peer.isBuildingOffer;

    if (hasCollision && peer.hasPriority) {
      RtcLogger.instance.log(
        'Offer collision on ${peer.remoteSessionId} (state: $signalingState). Polite peer rolling back local offer...',
        tag: 'COLLISION',
      );
      try {
        await peer.connection.setLocalDescription(RTCSessionDescription('', 'rollback'));
      } catch (e) {
        RtcLogger.instance.log('Rollback note: $e', tag: 'COLLISION');
      }
    }

    try {
      final description = RTCSessionDescription(sdpStr, typeStr);
      await peer.connection.setRemoteDescription(description);
      peer.remoteDescriptionSet = true;
      RtcLogger.instance.log('Remote description set from offer for ${peer.remoteSessionId}.', tag: 'SDP');

      // Flush queued candidates
      await peer.flushQueuedCandidates();

      // Ensure local tracks are attached before creating answer
      await _attachLocalMediaToPeer(peer);

      peer.isBuildingAnswer = true;
      final answer = await peer.connection.createAnswer();
      await peer.connection.setLocalDescription(answer);
      peer.isBuildingAnswer = false;

      RtcLogger.instance.log('Local answer set for ${peer.remoteSessionId}. Sending answer...', tag: 'SDP');

      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: [peer.remoteSessionId],
        channelId: _channelId,
        event: 'answer',
        payload: {
          'sdp': {'type': answer.type, 'sdp': answer.sdp},
        },
      );
    } catch (e) {
      peer.isBuildingAnswer = false;
      RtcLogger.instance.log('Error handling offer from ${peer.remoteSessionId}: $e', tag: 'SDP-ERROR');
    }
  }

  /// Handle incoming answer
  Future<void> _handleIncomingAnswer(RtcPeerSession peer, Map<String, dynamic> payload) async {
    final sdpData = payload['sdp'];
    if (sdpData is! Map) return;

    final sdpStr = sdpData['sdp'] as String? ?? '';
    final typeStr = sdpData['type'] as String? ?? 'answer';

    RtcLogger.instance.log('Processing incoming answer from session ${peer.remoteSessionId}...', tag: 'SDP');

    try {
      final description = RTCSessionDescription(sdpStr, typeStr);
      await peer.connection.setRemoteDescription(description);
      peer.remoteDescriptionSet = true;
      RtcLogger.instance.log('Remote description set from answer for ${peer.remoteSessionId}.', tag: 'SDP');

      await peer.flushQueuedCandidates();
    } catch (e) {
      RtcLogger.instance.log('Error setting remote answer for ${peer.remoteSessionId}: $e', tag: 'SDP-ERROR');
    }
  }

  /// Handle incoming candidate
  Future<void> _handleIncomingCandidate(RtcPeerSession peer, Map<String, dynamic> payload) async {
    final candData = payload['candidate'];
    if (candData is! Map) return;

    final candidateStr = candData['candidate'] as String? ?? '';
    final sdpMid = candData['sdpMid'] as String?;
    final sdpMLineIndex = candData['sdpMLineIndex'] as int? ?? 0;

    final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
    RtcLogger.instance.logCandidate(candidate, isLocal: false);

    if (!peer.remoteDescriptionSet) {
      peer.queueCandidate(candidate);
      return;
    }

    try {
      await peer.connection.addCandidate(candidate);
    } catch (e) {
      RtcLogger.instance.log('Failed to add candidate for ${peer.remoteSessionId}: $e', tag: 'ICE-ERROR');
    }
  }

  void _handleIncomingTrackChange(RtcPeerSession peer, Map<String, dynamic> payload) {
    RtcLogger.instance.log('trackChange from ${peer.remoteSessionId}: $payload', tag: 'MEDIA');
    final streamType = payload['type'] as String?;
    final active = payload['active'] == true;

    if (streamType == 'camera') {
      peer.isCameraActive = active;
    } else if (streamType == 'audio') {
      peer.isAudioActive = active;
    } else if (streamType == 'screen') {
      peer.isScreenSharingActive = active;
    }
    notifyListeners();
  }

  void _handleIceStateChange(RtcPeerSession peer, RTCIceConnectionState state) {
    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _status = CallStatus.connected;
      _cancelDiagnosisTimer();
      _startDurationTimer();

      try {
        Helper.setSpeakerphoneOn(_isSpeakerOn);
      } catch (_) {}

      // Unmute remote audio track
      peer.remoteStream?.getAudioTracks().forEach((track) => track.enabled = true);

      _sendDataChannelInfo(peer);

      RtcLogger.instance.evaluateDiagnosis(
        isConnected: true,
        iceState: state.name,
      );
      notifyListeners();
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      RtcLogger.instance.log('ICE failed on peer ${peer.remoteSessionId}. Triggering ICE restart...', tag: 'ICE');
      _restartIce(peer);
    }
  }

  Future<void> _restartIce(RtcPeerSession peer) async {
    try {
      final offer = await peer.connection.createOffer({'iceRestart': true});
      await peer.connection.setLocalDescription(offer);
      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: [peer.remoteSessionId],
        channelId: _channelId,
        event: 'offer',
        payload: {
          'sdp': {'type': offer.type, 'sdp': offer.sdp},
          'sequence': peer.sequence++,
        },
      );
    } catch (e) {
      RtcLogger.instance.log('Failed ICE restart: $e', tag: 'ICE');
    }
  }

  void _sendDataChannelInfo(RtcPeerSession peer) {
    final info = {
      'isSelfMuted': _isMuted,
      'isRaisingHand': false,
      'isDeaf': false,
      'isTalking': !_isMuted,
      'isCameraOn': _isVideo && !_isVideoOff,
      'isScreenSharingOn': _isScreenSharing,
    };
    _sendDataChannelMessage(peer, 'info', info);
  }

  void _sendDataChannelMessage(RtcPeerSession peer, String event, dynamic payload) {
    if (peer.dataChannel != null && peer.dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        peer.dataChannel!.send(RTCDataChannelMessage(
          jsonEncode({'event': event, 'channelId': _channelId, 'payload': payload}),
        ));
      } catch (_) {}
    }
  }

  void _handleDataChannelMessage(RtcPeerSession peer, String text) {
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final event = data['event'] as String?;
      final payload = data['payload'];

      if (event == 'info' && payload is Map) {
        peer.updateFromInfo(payload.cast<String, dynamic>());
        notifyListeners();
      }
    } catch (_) {}
  }

  void _handleRtcSessionsUpdate(int channelId, dynamic rtcSessions) {
    if (channelId != _channelId) return;

    if (rtcSessions is List) {
      for (final s in rtcSessions) {
        if (s is Map && s['id'] != null && s['id'] != _selfSessionId) {
          final id = s['id'] as int;
          if (!_peers.containsKey(id)) {
            RtcLogger.instance.log('Discovered new peer $id in sessions update. Connecting...', tag: 'MESH');
            _getOrCreatePeer(id);
          }
        }
      }
    }
  }

  void _handleSessionEnded(int sessionId) {
    _removePeer(sessionId);
    if (_peers.isEmpty && _status == CallStatus.connected) {
      RtcLogger.instance.log('All remote participants left the call.', tag: 'CALL');
      hangUp(remoteInitiated: true);
    }
  }

  Future<void> _removePeer(int sessionId) async {
    final peer = _peers.remove(sessionId);
    if (peer != null) {
      await peer.dispose();
      notifyListeners();
    }
  }

  /// Toggle microphone mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    for (final peer in _peers.values) {
      _sendDataChannelInfo(peer);
    }

    if (_selfSessionId != null) {
      _odooApi.updateAndBroadcast(
        sessionId: _selfSessionId!,
        values: {'is_muted': _isMuted},
      );
    }

    RtcLogger.instance.log('Microphone toggled: isMuted=$_isMuted', tag: 'MEDIA');
    notifyListeners();
  }

  /// Toggle camera video or upgrade voice call to video
  Future<void> toggleVideo() async {
    if (!_isVideo) {
      // Upgrade voice call to video call on the fly!
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) return;

      _isVideo = true;
      _isVideoOff = false;
      await initLocalRenderer();

      // Acquire camera stream
      try {
        final videoStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'mandatory': {'minWidth': '640', 'minHeight': '480', 'minFrameRate': '30'},
            'facingMode': 'user',
          },
        });
        final videoTrack = videoStream.getVideoTracks().firstOrNull;
        if (videoTrack != null) {
          _localStream?.addTrack(videoTrack);
          localRenderer.srcObject = _localStream;

          for (final peer in _peers.values) {
            final transceivers = await peer.connection.getTransceivers();
            if (transceivers.length >= 2) {
              await transceivers[1].sender.replaceTrack(videoTrack);
              await transceivers[1].setDirection(TransceiverDirection.SendRecv);
            }
            _sendDataChannelInfo(peer);
            _signalingService.sendSignal(
              senderSessionId: _selfSessionId!,
              targetSessionIds: [peer.remoteSessionId],
              channelId: _channelId,
              event: 'trackChange',
              payload: {'type': 'camera', 'active': true},
            );
          }
        }
      } catch (e) {
        RtcLogger.instance.log('Failed to upgrade to video: $e', tag: 'MEDIA');
      }
    } else {
      _isVideoOff = !_isVideoOff;
      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = !_isVideoOff;
      });

      for (final peer in _peers.values) {
        final transceivers = await peer.connection.getTransceivers();
        if (transceivers.length >= 2) {
          await transceivers[1].setDirection(
            _isVideoOff ? TransceiverDirection.RecvOnly : TransceiverDirection.SendRecv,
          );
        }
        _sendDataChannelInfo(peer);
        _signalingService.sendSignal(
          senderSessionId: _selfSessionId!,
          targetSessionIds: [peer.remoteSessionId],
          channelId: _channelId,
          event: 'trackChange',
          payload: {'type': 'camera', 'active': !_isVideoOff},
        );
      }
    }

    if (_selfSessionId != null) {
      _odooApi.updateAndBroadcast(
        sessionId: _selfSessionId!,
        values: {'is_camera_on': _isVideo && !_isVideoOff},
      );
    }

    RtcLogger.instance.log('Camera video toggled: isVideo=$_isVideo, isVideoOff=$_isVideoOff', tag: 'MEDIA');
    notifyListeners();
  }

  /// Flip front/back camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        try {
          await Helper.switchCamera(videoTracks[0]);
          RtcLogger.instance.log('Camera switched front/back.', tag: 'MEDIA');
        } catch (e) {
          RtcLogger.instance.log('Failed to switch camera: $e', tag: 'MEDIA');
        }
      }
    }
  }

  /// Toggle speakerphone
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      RtcLogger.instance.log('Speakerphone toggled: isSpeakerOn=$_isSpeakerOn', tag: 'MEDIA');
    } catch (e) {
      RtcLogger.instance.log('Failed to toggle speakerphone: $e', tag: 'MEDIA');
    }
    notifyListeners();
  }

  /// Toggle Screen Sharing using Android MediaProjection / DisplayMedia
  Future<void> toggleScreenShare() async {
    if (_isScreenSharing) {
      _isScreenSharing = false;
      if (_localScreenStream != null) {
        for (final t in _localScreenStream!.getTracks()) {
          t.stop();
        }
        await _localScreenStream!.dispose();
        _localScreenStream = null;
      }

      for (final peer in _peers.values) {
        final transceivers = await peer.connection.getTransceivers();
        if (transceivers.length >= 3) {
          await transceivers[2].sender.replaceTrack(null);
          await transceivers[2].setDirection(TransceiverDirection.RecvOnly);
        }
        _sendDataChannelInfo(peer);
        _signalingService.sendSignal(
          senderSessionId: _selfSessionId!,
          targetSessionIds: [peer.remoteSessionId],
          channelId: _channelId,
          event: 'trackChange',
          payload: {'type': 'screen', 'active': false},
        );
      }

      if (_selfSessionId != null) {
        _odooApi.updateAndBroadcast(
          sessionId: _selfSessionId!,
          values: {'is_screen_sharing_on': false},
        );
      }
      RtcLogger.instance.log('Screen sharing stopped.', tag: 'SCREEN');
    } else {
      try {
        _localScreenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': false,
        });
        _isScreenSharing = true;

        final screenTrack = _localScreenStream?.getVideoTracks().firstOrNull;
        if (screenTrack != null) {
          for (final peer in _peers.values) {
            final transceivers = await peer.connection.getTransceivers();
            if (transceivers.length >= 3) {
              await transceivers[2].sender.replaceTrack(screenTrack);
              await transceivers[2].setDirection(TransceiverDirection.SendRecv);
            }
            _sendDataChannelInfo(peer);
            _signalingService.sendSignal(
              senderSessionId: _selfSessionId!,
              targetSessionIds: [peer.remoteSessionId],
              channelId: _channelId,
              event: 'trackChange',
              payload: {'type': 'screen', 'active': true},
            );
          }
        }

        if (_selfSessionId != null) {
          _odooApi.updateAndBroadcast(
            sessionId: _selfSessionId!,
            values: {'is_screen_sharing_on': true},
          );
        }
        RtcLogger.instance.log('Screen sharing started.', tag: 'SCREEN');
      } catch (e) {
        RtcLogger.instance.log('Failed to start screen sharing: $e', tag: 'SCREEN');
      }
    }
    notifyListeners();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
      notifyListeners();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_channelId != 0 && _selfSessionId != null) {
        await _odooApi.pingChannel(
          channelId: _channelId,
          rtcSessionId: _selfSessionId!,
          checkRtcSessionIds: _peers.keys.toList(),
        );
      }
    });
  }

  void _startDiagnosisTimer() {
    _cancelDiagnosisTimer();
    _diagnosisTimer = Timer(const Duration(seconds: CallConfig.iceTimeoutSeconds), () {
      if (_status != CallStatus.connected && _status != CallStatus.ended) {
        RtcLogger.instance.log(
          'ICE Connection timed out after ${CallConfig.iceTimeoutSeconds}s without reaching connected state.',
          tag: 'DIAGNOSIS',
        );
        RtcLogger.instance.evaluateDiagnosis(
          isConnected: false,
          iceState: iceConnectionState,
        );
      }
    });
  }

  void _cancelDiagnosisTimer() {
    _diagnosisTimer?.cancel();
    _diagnosisTimer = null;
  }

  /// Periodic 3s Stats Inspector Timer (bytesSent, bytesReceived, candidate pair)
  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      for (final peer in _peers.values) {
        try {
          final stats = await peer.connection.getStats();
          for (final report in stats) {
            final values = report.values;
            if (report.type == 'outbound-rtp') {
              final kind = values['kind'] ?? values['mediaType'];
              final bytes = int.tryParse(values['bytesSent']?.toString() ?? '0') ?? 0;
              if (kind == 'audio') peer.bytesSentAudio = bytes;
              if (kind == 'video') peer.bytesSentVideo = bytes;
            } else if (report.type == 'inbound-rtp') {
              final kind = values['kind'] ?? values['mediaType'];
              final bytes = int.tryParse(values['bytesReceived']?.toString() ?? '0') ?? 0;
              if (kind == 'audio') peer.bytesReceivedAudio = bytes;
              if (kind == 'video') peer.bytesReceivedVideo = bytes;
            } else if (report.type == 'candidate-pair' && (values['state'] == 'succeeded' || values['selected'] == true)) {
              peer.selectedCandidatePair = 'pair=${values['localCandidateId']}->${values['remoteCandidateId']}';
            }
          }

          RtcLogger.instance.log(
            'STATS [Peer ${peer.remoteSessionId}]: Audio sent=${_fmt(peer.bytesSentAudio)} recv=${_fmt(peer.bytesReceivedAudio)} | Video sent=${_fmt(peer.bytesSentVideo)} recv=${_fmt(peer.bytesReceivedVideo)}',
            tag: 'STATS',
          );

          // Evaluate live media flow
          if (_status == CallStatus.connected) {
            if (peer.bytesReceivedAudio == 0 && peer.bytesSentAudio == 0 && _callDuration > 5) {
              RtcLogger.instance.log('WARNING: Media not flowing after 5s connected!', tag: 'DIAGNOSIS');
            }
          }
        } catch (_) {}
      }
    });
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Hang up and clean up all call resources
  Future<void> hangUp({bool remoteInitiated = false, bool notifyRemote = true}) async {
    RtcLogger.instance.log('HangUp initiated (remoteInitiated: $remoteInitiated)...', tag: 'CALL');

    _cancelDiagnosisTimer();
    _durationTimer?.cancel();
    _durationTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;

    // Send disconnect notification to peers if we initiated
    if (!remoteInitiated && notifyRemote && _selfSessionId != null && _peers.isNotEmpty) {
      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: _peers.keys.toList(),
        channelId: _channelId,
        event: 'disconnect',
        payload: {},
      );
    }

    // Dispose all peer connections
    for (final peer in _peers.values) {
      await peer.dispose();
    }
    _peers.clear();

    // Detach local renderers and tracks
    localRenderer.srcObject = null;
    if (_localStream != null) {
      for (final t in _localStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      try {
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    if (_localScreenStream != null) {
      for (final t in _localScreenStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      try {
        await _localScreenStream!.dispose();
      } catch (_) {}
      _localScreenStream = null;
    }

    // Leave call on Odoo server
    if (_channelId != 0) {
      await _odooApi.leaveCall(channelId: _channelId);
    }

    await _signalingService.disconnect();

    _status = CallStatus.ended;
    _selfSessionId = null;
    _isScreenSharing = false;
    _isJoining = false;

    RtcLogger.instance.log('Call terminated and all resources disposed.', tag: 'CALL');
    notifyListeners();
  }

  @override
  void dispose() {
    hangUp(remoteInitiated: false, notifyRemote: false);
    localRenderer.dispose();
    super.dispose();
  }
}
