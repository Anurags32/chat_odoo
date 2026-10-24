import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../config.dart';
import 'odoo_api.dart';
import 'signaling_service.dart';
import 'rtc_logger.dart';

enum CallStatus { idle, ringing, connecting, connected, ended, failed }

class RtcCallService extends ChangeNotifier {
  final OdooApi _odooApi;
  final SignalingService _signalingService;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  RTCRtpTransceiver? _audioTransceiver;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallStatus _status = CallStatus.idle;
  int _channelId = 0;
  int? _selfSessionId;
  List<int> _remoteSessionIds = [];

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _callDuration = 0;
  Timer? _durationTimer;
  Timer? _diagnosisTimer;
  Timer? _pingTimer;
  Timer? _offerFallbackTimer;

  // Inbound notifications queue for serial execution
  Future<void> _inbound = Future.value();

  // Queued remote ICE candidates received prior to setRemoteDescription
  final List<RTCIceCandidate> _queuedRemoteCandidates = [];
  bool _remoteDescriptionSet = false;

  // Connection states
  String _iceConnectionState = 'new';
  String _peerConnectionState = 'new';

  CallStatus get status => _status;
  int get channelId => _channelId;
  int? get selfSessionId => _selfSessionId;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  int get callDuration => _callDuration;
  String get iceConnectionState => _iceConnectionState;
  String get peerConnectionState => _peerConnectionState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

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

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      RtcLogger.instance.log(
        'Microphone permission DENIED by user.',
        tag: 'PERM',
      );
      return false;
    }
    RtcLogger.instance.log('Microphone permission GRANTED.', tag: 'PERM');
    return true;
  }

  /// Start or join a voice call on the given Odoo Discuss channel
  Future<bool> joinCall({
    required int channelId,
    bool createOfferIfFirst = true,
  }) async {
    RtcLogger.instance.resetCounters();
    RtcLogger.instance.log(
      'Starting joinCall flow on channel $channelId...',
      tag: 'CALL',
    );

    _channelId = channelId;
    _status = CallStatus.connecting;
    _callDuration = 0;
    _queuedRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    notifyListeners();

    // 1. Ensure microphone permission
    final hasMic = await requestMicrophonePermission();
    if (!hasMic) {
      _status = CallStatus.failed;
      RtcLogger.instance.log(
        'Cannot initiate call without microphone permission.',
        tag: 'CALL',
      );
      notifyListeners();
      return false;
    }

    // 2. Start 20s diagnosis timer for ICE connection
    _startDiagnosisTimer();

    // 3. Connect Signaling WebSocket to channel bus
    await _signalingService.connect(channelId: channelId);

    // 4. Join call via Odoo HTTP JSON-RPC
    final joinResult = await _odooApi.joinCall(channelId: channelId);
    if (joinResult.containsKey('error') || joinResult['sessionId'] == null) {
      RtcLogger.instance.log(
        'Failed to join call via Odoo: ${joinResult['error']}',
        tag: 'CALL',
      );
      _status = CallStatus.failed;
      notifyListeners();
      return false;
    }

    _selfSessionId = joinResult['sessionId'] as int;
    final odooIceServers = joinResult['iceServers'] as List? ?? [];
    final rtcSessions = joinResult['rtcSessions'] as List? ?? [];

    RtcLogger.instance.log(
      'Joined Odoo Call! selfSessionId=$_selfSessionId | iceServers=${odooIceServers.length} | otherSessions=${rtcSessions.length}',
      tag: 'CALL',
    );

    // Track remote session IDs in the channel
    _remoteSessionIds = [];
    for (final s in rtcSessions) {
      if (s is Map && s['id'] != null && s['id'] != _selfSessionId) {
        _remoteSessionIds.add(s['id'] as int);
      }
    }

    // 5. Initialize WebRTC Peer Connection with iceServers from Odoo (or STUN fallback)
    await _initPeerConnection(odooIceServers);

    // 6. Acquire local microphone audio track
    await _createLocalAudioStream();

    // 7. Handle call initiation/answer:
    // If remote sessions already exist in the channel (e.g. Odoo web user is waiting),
    // Odoo's web client automatically sends an offer when detecting our join.
    // We wait up to 2.5s for their offer, and only create an offer ourselves if none arrives.
    if (_remoteSessionIds.isNotEmpty && createOfferIfFirst) {
      RtcLogger.instance.log(
        'Remote sessions detected ($_remoteSessionIds). Waiting for incoming offer with 2.5s fallback...',
        tag: 'CALL',
      );
      _offerFallbackTimer?.cancel();
      _offerFallbackTimer = Timer(const Duration(milliseconds: 2500), () {
        if (_peerConnection != null &&
            _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateStable &&
            !_remoteDescriptionSet) {
          RtcLogger.instance.log(
            'No offer received from remote within 2.5s; initiating offer now...',
            tag: 'CALL',
          );
          _createAndSendOffer();
        }
      });
    } else {
      RtcLogger.instance.log(
        'Waiting for peer connection or incoming offer from remote participants...',
        tag: 'CALL',
      );
    }

    // 8. Odoo 18 periodic call keep-alive (pings /discuss/channel/ping every 30s)
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_channelId != 0 && _selfSessionId != null) {
        await _odooApi.pingChannel(
          channelId: _channelId,
          rtcSessionId: _selfSessionId!,
          checkRtcSessionIds: _remoteSessionIds,
        );
      }
    });

    notifyListeners();
    return true;
  }

  /// Initialize RTCPeerConnection with mandatory debug listeners
  Future<void> _initPeerConnection(List<dynamic> iceServersFromOdoo) async {
    // Transform Odoo ICE server format if necessary or use fallback
    List<Map<String, dynamic>> iceServers = [];

    if (iceServersFromOdoo.isNotEmpty) {
      for (final item in iceServersFromOdoo) {
        if (item is Map) {
          iceServers.add(Map<String, dynamic>.from(item));
        }
      }
      RtcLogger.instance.log(
        'Using ICE servers provided by Odoo (${iceServers.length} servers).',
        tag: 'ICE-CONFIG',
      );
    }

    if (iceServers.isEmpty) {
      iceServers = List<Map<String, dynamic>>.from(CallConfig.stunFallback);
      RtcLogger.instance.log(
        'No ICE servers from Odoo; using STUN fallback: $iceServers',
        tag: 'ICE-CONFIG',
      );
    }

    final configuration = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    RtcLogger.instance.log(
      'Creating PeerConnection with configuration: $configuration',
      tag: 'WEBRTC',
    );
    _peerConnection = await createPeerConnection(configuration);

    // ── Odoo 18 Negotiated DataChannel "notifications" (id: 1) ─────────────
    // Odoo browser UI will NOT show remote track or play audio until "broadcast" is sent
    try {
      _dataChannel = await _peerConnection!.createDataChannel(
        'notifications',
        RTCDataChannelInit()
          ..negotiated = true
          ..id = 1,
      );
      _dataChannel!.onDataChannelState = (RTCDataChannelState s) {
        RtcLogger.instance.log('DataChannel state: $s', tag: 'DATA-CHANNEL');
        if (s == RTCDataChannelState.RTCDataChannelOpen) {
          _sendDataChannelMessage('info', {
            'isSelfMuted': _isMuted,
            'isRaisingHand': false,
            'isDeaf': false,
            'isTalking': false,
            'isCameraOn': false,
            'isScreenSharingOn': false,
          });
          _sendDataChannelMessage('broadcast', {'sequence': 0});
          RtcLogger.instance.log('Sent DataChannel "broadcast" & "info" frames to peer.', tag: 'DATA-CHANNEL');
        }
      };
      _dataChannel!.onMessage = (RTCDataChannelMessage m) {
        RtcLogger.instance.log('DataChannel message: ${m.text}', tag: 'DATA-CHANNEL');
        _inbound = _inbound.then((_) => _handleDataChannelMessage(m.text));
      };
    } catch (e) {
      RtcLogger.instance.log('Failed to create DataChannel: $e', tag: 'DATA-CHANNEL');
    }

    // Remote-initiated DataChannel listener (id: 1 "notifications")
    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      RtcLogger.instance.log('Remote DataChannel received: ${channel.label} (id: ${channel.id})', tag: 'DATA-CHANNEL');
      _dataChannel = channel;
      channel.onDataChannelState = (RTCDataChannelState s) {
        RtcLogger.instance.log('DataChannel state: $s', tag: 'DATA-CHANNEL');
        if (s == RTCDataChannelState.RTCDataChannelOpen) {
          _sendDataChannelMessage('info', {
            'isSelfMuted': _isMuted,
            'isRaisingHand': false,
            'isDeaf': false,
            'isTalking': false,
            'isCameraOn': false,
            'isScreenSharingOn': false,
          });
          _sendDataChannelMessage('broadcast', {'sequence': 0});
          RtcLogger.instance.log('Sent DataChannel "broadcast" & "info" frames on remote channel.', tag: 'DATA-CHANNEL');
        }
      };
      channel.onMessage = (RTCDataChannelMessage m) {
        RtcLogger.instance.log('DataChannel message: ${m.text}', tag: 'DATA-CHANNEL');
        _inbound = _inbound.then((_) => _handleDataChannelMessage(m.text));
      };
    };

    // ── Odoo 18 Fixed Transceiver Order: 1 Audio (SendRecv), 2 Video (RecvOnly) ──
    try {
      _audioTransceiver = await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      for (var i = 0; i < 2; i++) {
        await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      }
      RtcLogger.instance.log('Configured 3 Unified Plan transceivers (audio, camera, screen).', tag: 'WEBRTC');
    } catch (e) {
      RtcLogger.instance.log('Failed to configure transceivers: $e', tag: 'WEBRTC');
    }

    // ── MANDATORY DEBUG LISTENERS ──────────────────────────────────────────
    _peerConnection!.onIceConnectionState = (s) {
      _iceConnectionState = s.name;
      RtcLogger.instance.log('ICE: $s');
      _handleIceConnectionStateChange(s);
    };

    _peerConnection!.onConnectionState = (s) {
      _peerConnectionState = s.name;
      RtcLogger.instance.log('PC: $s');
      _handlePeerConnectionStateChange(s);
    };

    _peerConnection!.onIceGatheringState = (s) {
      RtcLogger.instance.log('GATHER: $s');
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        RtcLogger.instance.logGatheringComplete();
      }
    };

    _peerConnection!.onSignalingState = (s) {
      RtcLogger.instance.log('SIGNALING: $s');
    };

    _peerConnection!.onIceCandidate = (c) {
      RtcLogger.instance.log('candidate: ${c.candidate}');
      RtcLogger.instance.logCandidate(c, isLocal: true);
      _sendLocalIceCandidate(c);
    };
    // ────────────────────────────────────────────────────────────────────────

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      RtcLogger.instance.log(
        'Remote track received: kind=${event.track.kind}',
        tag: 'WEBRTC',
      );
      if (event.track.kind == 'audio') {
        _remoteStream = event.streams.isNotEmpty ? event.streams[0] : null;
        notifyListeners();
      }
    };

    RtcLogger.instance.log(
      'PeerConnection initialized successfully.',
      tag: 'WEBRTC',
    );
  }

  /// Create local audio-only stream (getUserMedia({'audio': true, 'video': false}))
  Future<void> _createLocalAudioStream() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _isMuted = false;

      // Attach audio track to the audio transceiver (Unified Plan)
      await _attachLocalAudio();

      RtcLogger.instance.log(
        'Local audio stream created and track attached.',
        tag: 'MEDIA',
      );
    } catch (e) {
      RtcLogger.instance.log(
        'Failed to acquire microphone stream: $e',
        tag: 'MEDIA',
      );
    }
  }

  /// Attach local microphone audio track to the Audio transceiver
  Future<void> _attachLocalAudio() async {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track == null || _peerConnection == null) return;
    try {
      if (_audioTransceiver != null) {
        await _audioTransceiver!.sender.replaceTrack(track);
        await _audioTransceiver!.setDirection(TransceiverDirection.SendRecv);
      } else {
        final transceivers = await _peerConnection!.getTransceivers();
        if (transceivers.isNotEmpty) {
          final audio = transceivers.first;
          await audio.sender.replaceTrack(track);
          await audio.setDirection(TransceiverDirection.SendRecv);
        } else {
          for (final t in _localStream!.getAudioTracks()) {
            await _peerConnection?.addTrack(t, _localStream!);
          }
        }
      }
    } catch (e) {
      RtcLogger.instance.log('Failed to attach local audio track: $e', tag: 'MEDIA');
    }
  }

  void _sendDataChannelMessage(String event, Map<String, dynamic> payload) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(
          jsonEncode({'event': event, 'channelId': _channelId, 'payload': payload}),
        ));
      } catch (e) {
        RtcLogger.instance.log('Failed to send DataChannel message: $e', tag: 'DATA-CHANNEL');
      }
    }
  }

  Future<void> _handleDataChannelMessage(String text) async {
    try {
      final msg = jsonDecode(text) as Map<String, dynamic>;
      final event = msg['event'] as String?;
      RtcLogger.instance.log('<- DataChannel event: $event', tag: 'DATA-CHANNEL');
    } catch (e) {
      RtcLogger.instance.log('DataChannel json error: $e', tag: 'DATA-CHANNEL');
    }
  }

  /// Create local offer and send via notify_call_members
  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null || _selfSessionId == null) return;

    try {
      final offer = await _peerConnection!.createOffer();

      await _peerConnection!.setLocalDescription(offer);
      RtcLogger.instance.log('Local offer description set.', tag: 'SDP');

      final targets = _remoteSessionIds.isNotEmpty ? _remoteSessionIds : [0];
      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: targets,
        channelId: _channelId,
        event: 'offer',
        payload: {
          'sdp': {'type': offer.type, 'sdp': offer.sdp},
          'sequence': 0,
        },
      );
    } catch (e) {
      RtcLogger.instance.log('Failed to create/send offer: $e', tag: 'SDP');
    }
  }

  /// Handle incoming bus peer notification (offer, answer, ice-candidate, disconnect)
  Future<void> _handlePeerNotification(
    int senderSessionId,
    String event,
    Map<String, dynamic> payload,
  ) {
    _inbound = _inbound.then((_) => _processPeerNotification(senderSessionId, event, payload));
    return _inbound;
  }

  Future<void> _processPeerNotification(
    int senderSessionId,
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (senderSessionId == _selfSessionId) return;

    if (!_remoteSessionIds.contains(senderSessionId)) {
      _remoteSessionIds.add(senderSessionId);
    }

    switch (event) {
      case 'offer':
        await _handleIncomingOffer(senderSessionId, payload);
        break;
      case 'answer':
        await _handleIncomingAnswer(senderSessionId, payload);
        break;
      case 'ice-candidate':
        await _handleIncomingCandidate(senderSessionId, payload);
        break;
      case 'disconnect':
        RtcLogger.instance.log(
          'Remote peer cleanly disconnected: $senderSessionId',
          tag: 'SIGNAL',
        );
        hangUp(remoteInitiated: true);
        break;
    }
  }

  /// Handle incoming SDP Offer with Polite Peer / Collision handling
  Future<void> _handleIncomingOffer(
    int senderSessionId,
    Map<String, dynamic> payload,
  ) async {
    if (_peerConnection == null) return;

    final sdpData = payload['sdp'];
    if (sdpData is! Map) return;

    final sdpStr = sdpData['sdp'] as String? ?? '';
    final typeStr = sdpData['type'] as String? ?? 'offer';

    RtcLogger.instance.log(
      'Processing incoming offer from session $senderSessionId...',
      tag: 'SDP',
    );

    _offerFallbackTimer?.cancel();

    // Polite Peer logic for offer collision
    final signalingState = _peerConnection!.signalingState;
    final isCollision =
        signalingState != RTCSignalingState.RTCSignalingStateStable;

    if (isCollision) {
      RtcLogger.instance.log(
        'Offer collision detected (state: $signalingState). Rolling back local offer to answer incoming offer...',
        tag: 'COLLISION',
      );
      try {
        await _peerConnection!.setLocalDescription(
          RTCSessionDescription('', 'rollback'),
        );
      } catch (e) {
        RtcLogger.instance.log('Rollback note: $e', tag: 'COLLISION');
      }
    }

    try {
      final description = RTCSessionDescription(sdpStr, typeStr);
      await _peerConnection!.setRemoteDescription(description);
      _remoteDescriptionSet = true;
      RtcLogger.instance.log(
        'Remote description set from incoming offer.',
        tag: 'SDP',
      );

      // Flush queued remote ICE candidates
      await _flushQueuedCandidates();

      // Attach local microphone audio before building answer
      await _attachLocalAudio();

      // Create and send answer (pure Unified Plan)
      final answer = await _peerConnection!.createAnswer();

      await _peerConnection!.setLocalDescription(answer);
      RtcLogger.instance.log('Local answer description set.', tag: 'SDP');

      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: [senderSessionId],
        channelId: _channelId,
        event: 'answer',
        payload: {
          'sdp': {'type': answer.type, 'sdp': answer.sdp},
        },
      );
    } catch (e) {
      RtcLogger.instance.log(
        'Error handling remote offer: $e',
        tag: 'SDP-ERROR',
      );
    }
  }

  /// Handle incoming SDP Answer
  Future<void> _handleIncomingAnswer(
    int senderSessionId,
    Map<String, dynamic> payload,
  ) async {
    if (_peerConnection == null) return;

    final sdpData = payload['sdp'];
    if (sdpData is! Map) return;

    final sdpStr = sdpData['sdp'] as String? ?? '';
    final typeStr = sdpData['type'] as String? ?? 'answer';

    RtcLogger.instance.log(
      'Processing incoming answer from session $senderSessionId...',
      tag: 'SDP',
    );

    try {
      final description = RTCSessionDescription(sdpStr, typeStr);
      await _peerConnection!.setRemoteDescription(description);
      _remoteDescriptionSet = true;
      RtcLogger.instance.log(
        'Remote description set from incoming answer.',
        tag: 'SDP',
      );

      // Flush queued remote ICE candidates
      await _flushQueuedCandidates();
    } catch (e) {
      RtcLogger.instance.log(
        'Error setting remote description from answer: $e',
        tag: 'SDP-ERROR',
      );
    }
  }

  /// Handle incoming ICE candidate (queue if remoteDescription is not yet set)
  Future<void> _handleIncomingCandidate(
    int senderSessionId,
    Map<String, dynamic> payload,
  ) async {
    final candData = payload['candidate'];
    if (candData is! Map) return;

    final candidateStr = candData['candidate'] as String? ?? '';
    final sdpMid = candData['sdpMid'] as String?;
    final sdpMLineIndex = candData['sdpMLineIndex'] as int? ?? 0;

    final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
    RtcLogger.instance.logCandidate(candidate, isLocal: false);

    if (!_remoteDescriptionSet || _peerConnection == null) {
      RtcLogger.instance.log(
        'Queueing remote ICE candidate (remoteDescription not set yet). Total queued: ${_queuedRemoteCandidates.length + 1}',
        tag: 'ICE-QUEUE',
      );
      _queuedRemoteCandidates.add(candidate);
      return;
    }

    try {
      await _peerConnection!.addCandidate(candidate);
      RtcLogger.instance.log(
        'Added remote ICE candidate to PeerConnection.',
        tag: 'ICE',
      );
    } catch (e) {
      RtcLogger.instance.log(
        'Failed to add remote ICE candidate: $e',
        tag: 'ICE-ERROR',
      );
    }
  }

  /// Flush remote ICE candidates after setRemoteDescription
  Future<void> _flushQueuedCandidates() async {
    if (_queuedRemoteCandidates.isEmpty) return;

    RtcLogger.instance.log(
      'Flushing ${_queuedRemoteCandidates.length} queued remote ICE candidates...',
      tag: 'ICE-QUEUE',
    );

    for (final candidate in List<RTCIceCandidate>.from(
      _queuedRemoteCandidates,
    )) {
      try {
        await _peerConnection?.addCandidate(candidate);
        RtcLogger.instance.log(
          'Flushed queued candidate: ${candidate.candidate}',
          tag: 'ICE-QUEUE',
        );
      } catch (e) {
        RtcLogger.instance.log(
          'Error adding queued candidate: $e',
          tag: 'ICE-ERROR',
        );
      }
    }
    _queuedRemoteCandidates.clear();
  }

  /// Send local ICE candidate to remote sessions via notify_call_members
  void _sendLocalIceCandidate(RTCIceCandidate candidate) {
    if (_selfSessionId == null || _channelId == 0) return;

    final candMap = {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };

    final targets = _remoteSessionIds.isNotEmpty ? _remoteSessionIds : [0];

    // Enqueue candidate with 100ms debounced batching (Odoo peer_to_peer.js pattern)
    _signalingService.enqueueSignal(
      senderSessionId: _selfSessionId!,
      targetSessionIds: targets,
      channelId: _channelId,
      event: 'ice-candidate',
      payload: {'candidate': candMap},
    );
  }

  void _handleIceConnectionStateChange(RTCIceConnectionState state) {
    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _status = CallStatus.connected;
      _cancelDiagnosisTimer();
      _startDurationTimer();
      RtcLogger.instance.evaluateDiagnosis(
        isConnected: true,
        iceState: state.name,
      );
      notifyListeners();
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      _status = CallStatus.failed;
      _cancelDiagnosisTimer();
      RtcLogger.instance.evaluateDiagnosis(
        isConnected: false,
        iceState: state.name,
      );
      notifyListeners();
    }
  }

  void _handlePeerConnectionStateChange(RTCPeerConnectionState state) {
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _status = CallStatus.connected;
      _cancelDiagnosisTimer();
      _startDurationTimer();
      notifyListeners();
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      _status = CallStatus.failed;
      _cancelDiagnosisTimer();
      RtcLogger.instance.evaluateDiagnosis(
        isConnected: false,
        iceState: _iceConnectionState,
      );
      notifyListeners();
    }
  }

  void _handleRtcSessionsUpdate(int channelId, dynamic rtcSessions) {
    if (channelId != _channelId) return;

    if (rtcSessions is List) {
      for (final s in rtcSessions) {
        if (s is Map && s['id'] != null && s['id'] != _selfSessionId) {
          final id = s['id'] as int;
          if (!_remoteSessionIds.contains(id)) {
            _remoteSessionIds.add(id);
            RtcLogger.instance.log(
              'Discovered new participant session in channel: $id',
              tag: 'SESSION',
            );
          }
        }
      }
    }
  }

  void _handleSessionEnded(int sessionId) {
    _remoteSessionIds.remove(sessionId);
    RtcLogger.instance.log(
      'Session ended: $sessionId (remaining: $_remoteSessionIds)',
      tag: 'SESSION',
    );
    if (_remoteSessionIds.isEmpty && _status == CallStatus.connected) {
      RtcLogger.instance.log(
        'All remote participants left the call.',
        tag: 'CALL',
      );
      hangUp(remoteInitiated: true);
    }
  }

  /// Start 20s diagnosis timer
  void _startDiagnosisTimer() {
    _cancelDiagnosisTimer();
    _diagnosisTimer = Timer(
      const Duration(seconds: CallConfig.iceTimeoutSeconds),
      () {
        if (_status != CallStatus.connected && _status != CallStatus.ended) {
          RtcLogger.instance.log(
            'ICE Connection timed out after ${CallConfig.iceTimeoutSeconds}s without reaching connected state.',
            tag: 'DIAGNOSIS',
          );
          RtcLogger.instance.evaluateDiagnosis(
            isConnected: false,
            iceState: _iceConnectionState,
          );
        }
      },
    );
  }

  void _cancelDiagnosisTimer() {
    _diagnosisTimer?.cancel();
    _diagnosisTimer = null;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });
  }

  /// Toggle microphone mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    _sendDataChannelMessage('info', {
      'isSelfMuted': _isMuted,
      'isRaisingHand': false,
      'isDeaf': false,
      'isTalking': false,
      'isCameraOn': false,
      'isScreenSharingOn': false,
    });

    if (_selfSessionId != null) {
      _odooApi.updateAndBroadcast(
        sessionId: _selfSessionId!,
        values: {'is_muted': _isMuted},
      );
    }

    RtcLogger.instance.log(
      'Microphone toggled: isMuted=$_isMuted',
      tag: 'MEDIA',
    );
    notifyListeners();
  }

  /// Toggle speakerphone
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      RtcLogger.instance.log(
        'Speakerphone toggled: isSpeakerOn=$_isSpeakerOn',
        tag: 'MEDIA',
      );
    } catch (e) {
      RtcLogger.instance.log('Failed to toggle speakerphone: $e', tag: 'MEDIA');
    }
    notifyListeners();
  }

  /// Hang up and clean up all resources
  Future<void> hangUp({bool remoteInitiated = false}) async {
    RtcLogger.instance.log(
      'HangUp initiated (remoteInitiated=$remoteInitiated)...',
      tag: 'CALL',
    );

    _cancelDiagnosisTimer();
    _durationTimer?.cancel();
    _durationTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _offerFallbackTimer?.cancel();
    _offerFallbackTimer = null;

    // 1. Inspect getStats() on hangup to log the selected candidate pair
    await RtcLogger.instance.inspectStatsOnHangup(_peerConnection);

    // 2. Notify remote peers of disconnect if we initiated
    if (!remoteInitiated &&
        _selfSessionId != null &&
        _remoteSessionIds.isNotEmpty) {
      await _signalingService.sendSignal(
        senderSessionId: _selfSessionId!,
        targetSessionIds: _remoteSessionIds,
        channelId: _channelId,
        event: 'disconnect',
        payload: {},
      );
    }

    // 3. Close data channel
    try {
      await _dataChannel?.close();
    } catch (_) {}
    _dataChannel = null;
    _audioTransceiver = null;

    // 4. Stop and dispose local audio tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // 5. Dispose peer connection
    if (_peerConnection != null) {
      await _peerConnection!.close();
      await _peerConnection!.dispose();
      _peerConnection = null;
    }

    // 6. Leave call on Odoo server
    if (_channelId != 0) {
      await _odooApi.leaveCall(channelId: _channelId);
    }

    // 7. Disconnect signaling bus
    await _signalingService.disconnect();

    _queuedRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _status = CallStatus.ended;
    _remoteSessionIds = [];
    _selfSessionId = null;

    RtcLogger.instance.log(
      'Call cleanly terminated and resources disposed.',
      tag: 'CALL',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    hangUp();
    super.dispose();
  }
}
