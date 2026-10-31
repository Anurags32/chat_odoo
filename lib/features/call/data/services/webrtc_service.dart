import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/call_model.dart';
import '../models/ice_server_model.dart';

typedef OnIceCandidateCallback = void Function(RTCIceCandidate candidate);
typedef OnConnectionStateCallback = void Function(RTCPeerConnectionState state);
typedef OnTrackCallback = void Function(MediaStream stream);

/// Odoo 18 ke browser client se compatible WebRTC service.
///
/// PURANI FILE SE KYA BADLA (search "ODOO FIX"):
///  1. Odoo wala negotiated data channel (id 1, "notifications") add hua.
///     Iske bina Odoo browser remote audio/video ko "ready" nahi maanta.
///  2. 3 transceivers fixed order me: audio, camera, screen (Odoo ka order).
///  3. onTrack: Odoo track bina stream ke bhejta hai, usko handle kiya.
///  4. Speakerphone Helper.setSpeakerphoneOn se.
///  5. logStats() debugging ke liye.
///
/// USE KARNE SE PEHLE:
///   webRtc.channelId = <discuss.channel ka id>;   // partner id NAHI
///   await webRtc.startLocalStream(callType);
///   await webRtc.createPeerConnectionInstance(iceServers);
class WebRtcService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _isInitialized = false;
  bool _isAudioMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;

  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // ODOO FIX: discuss.channel ka id. Data channel ke messages me jaata hai.
  int? channelId;

  // ODOO FIX: negotiated data channel
  RTCDataChannel? _dataChannel;
  Timer? _statsTimer;

  // ICE Candidate Queue (queue candidates until remote description is set)
  final List<RTCIceCandidate> _queuedRemoteCandidates = [];
  bool _hasRemoteDescription = false;

  OnIceCandidateCallback? onIceCandidate;
  OnConnectionStateCallback? onConnectionStateChange;
  OnTrackCallback? onRemoteStreamAdded;
  VoidCallback? onCallEnded;

  /// ODOO FIX: Odoo me pehla offer sirf data-channel ka hota hai. Jo answer deta hai
  /// wahi media transceivers add karke NAYA offer bhejta hai. Is callback me
  /// createOffer() karke offer Odoo ko bhejo (sequence ke saath), warna awaaz nahi aayegi.
  VoidCallback? onNegotiationNeeded;

  bool get isSignalingStable =>
      _peerConnection?.signalingState ==
      RTCSignalingState.RTCSignalingStateStable;

  /// Initialize video renderers
  Future<void> initRenderers() async {
    if (_isInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isInitialized = true;
    debugPrint('[WebRTC] Renderers initialized.');
  }

  /// Request runtime permissions for Camera and Microphone
  Future<bool> requestPermissions(CallType callType) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('[WebRTC] Microphone permission denied.');
      return false;
    }

    if (callType == CallType.video) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        debugPrint('[WebRTC] Camera permission denied.');
        return false;
      }
    }
    return true;
  }

  /// Create local media stream (Mic and/or Camera)
  Future<MediaStream?> startLocalStream(CallType callType) async {
    final hasPermission = await requestPermissions(callType);
    if (!hasPermission) return null;

    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': callType == CallType.video
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
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      localRenderer.srcObject = _localStream;
      _isAudioMuted = false;
      _isVideoOff = callType != CallType.video;

      // Keep screen awake during active calls
      await WakelockPlus.enable();
      return _localStream;
    } catch (e) {
      debugPrint('[WebRTC] Failed to get user media: $e');
      return null;
    }
  }

  /// Setup RTCPeerConnection with dynamic ICE servers (STUN/TURN)
  Future<bool> createPeerConnectionInstance(
    List<IceServerModel> iceServers,
  ) async {
    // Agar Odoo se iceServers khali/false aaye to Google STUN use karo
    final servers = iceServers.isEmpty
        ? [
            {
              'urls': [
                'stun:stun1.l.google.com:19302',
                'stun:stun2.l.google.com:19302',
              ],
            },
          ]
        : iceServers.map((s) => s.toMap()).toList();

    final Map<String, dynamic> configuration = {
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'balanced',
    };

    final Map<String, dynamic> loopbackConstraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    try {
      _peerConnection = await createPeerConnection(
        configuration,
        loopbackConstraints,
      );

      // ODOO FIX 1: negotiated data channel (id 1). Transceivers se PEHLE banao.
      await _setupDataChannel();

      // ODOO FIX 2: Odoo ka fixed order: [0]=audio, [1]=camera, [2]=screen
      final audioT = await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      final cameraT = await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo, // screen (use nahi hota)
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // Local tracks attach karo
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          await audioT.sender.replaceTrack(audioTracks.first);
        }
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          await cameraT.sender.replaceTrack(videoTracks.first);
          await cameraT.setDirection(TransceiverDirection.SendRecv);
        }
      }

      _peerConnection!.onRenegotiationNeeded = () {
        debugPrint('[WebRTC] negotiationneeded');
        onNegotiationNeeded?.call();
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          debugPrint(
            '[WebRTC] Local ICE candidate generated: ${candidate.candidate}',
          );
          onIceCandidate?.call(candidate);
        }
      };

      // ODOO FIX 3: Odoo browser track bina stream ke bhejta hai (replaceTrack),
      // isliye event.streams khali aa sakta hai. Us case me khud stream banao.
      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
        MediaStream stream;
        if (event.streams.isNotEmpty) {
          stream = event.streams[0];
        } else {
          _remoteStream ??= await createLocalMediaStream('odoo_remote');
          _remoteStream!.addTrack(event.track);
          stream = _remoteStream!;
        }
        _remoteStream = stream;
        remoteRenderer.srcObject = stream;
        onRemoteStreamAdded?.call(stream);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[WebRTC] ICE state: $state');
      };

      // Listen for connection state changes
      _peerConnection!
          .onConnectionState = (RTCPeerConnectionState state) async {
        debugPrint('[WebRTC] PeerConnection state changed: $state');
        onConnectionStateChange?.call(state);

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          // ODOO FIX 4: speaker Helper se
          await Helper.setSpeakerphoneOn(_isSpeakerOn);
          _startStatsLogging();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          // NOTE: restartIce() ka offer caller ko Odoo ke notify_call_members
          // se bhejna hoga. Abhi sirf log hota hai.
          debugPrint('[WebRTC] Connection failed. Triggering ICE restart...');
          restartIce();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // NOTE: Disconnected pe call end nahi karte, wo kai baar temporary hota hai.
          onCallEnded?.call();
        }
      };

      return true;
    } catch (e) {
      debugPrint('[WebRTC] Error creating RTCPeerConnection: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // ODOO FIX 1: data channel
  // ---------------------------------------------------------------------
  Future<void> _setupDataChannel() async {
    _dataChannel = await _peerConnection!.createDataChannel(
      'notifications',
      RTCDataChannelInit()
        ..negotiated = true
        ..id = 1,
    );

    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      debugPrint('[DC] state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        // Odoo isi message se "peer ready" maanta hai aur tab hi media dikhata/bhejta hai.
        _dcSend('info', {
          'isSelfMuted': _isAudioMuted,
          'isRaisingHand': false,
          'isDeaf': false,
          'isTalking': false,
          'isCameraOn': !_isVideoOff,
          'isScreenSharingOn': false,
        });
        _dcSend('broadcast', {'sequence': 0});
      }
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage m) {
      debugPrint('[DC] <- ${m.text}');
    };
  }

  void _dcSend(String event, Map<String, dynamic> payload) {
    final dc = _dataChannel;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen)
      return;
    dc.send(
      RTCDataChannelMessage(
        jsonEncode({
          'event': event,
          'channelId': channelId,
          'payload': payload,
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Offer / Answer
  // ---------------------------------------------------------------------

  /// Create and set local SDP Offer
  Future<RTCSessionDescription?> createOffer() async {
    if (_peerConnection == null) return null;
    try {
      // Transceivers pehle se bane hain, isliye offerToReceive* ki zarurat nahi.
      final RTCSessionDescription description = await _peerConnection!
          .createOffer();
      await _peerConnection!.setLocalDescription(description);
      debugPrint('[WebRTC] Local offer set successfully.');
      return description;
    } catch (e) {
      debugPrint('[WebRTC] Error creating offer: $e');
      return null;
    }
  }

  /// Handle incoming remote SDP Offer and create Answer
  Future<RTCSessionDescription?> handleRemoteOfferAndCreateAnswer(
    Map<String, dynamic> sdpMap,
  ) async {
    if (_peerConnection == null) return null;
    try {
      final remoteDesc = RTCSessionDescription(
        sdpMap['sdp'] as String,
        sdpMap['type'] as String? ?? 'offer',
      );
      await _peerConnection!.setRemoteDescription(remoteDesc);
      _hasRemoteDescription = true;
      debugPrint('[WebRTC] Remote offer set. Flushing candidate queue...');
      await _drainCandidateQueue();

      final RTCSessionDescription answer = await _peerConnection!
          .createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[WebRTC] Local answer set successfully.');
      return answer;
    } catch (e) {
      debugPrint(
        '[WebRTC] Error handling remote offer and creating answer: $e',
      );
      return null;
    }
  }

  /// Handle incoming remote SDP Answer
  Future<void> handleRemoteAnswer(Map<String, dynamic> sdpMap) async {
    if (_peerConnection == null) return;
    try {
      final st = _peerConnection!.signalingState;
      if (st == RTCSignalingState.RTCSignalingStateStable ||
          st == RTCSignalingState.RTCSignalingStateHaveRemoteOffer ||
          st == null) {
        debugPrint('[WebRTC] Ignoring redundant answer: invalid signaling state $st');
        return;
      }
      final remoteDesc = RTCSessionDescription(
        sdpMap['sdp'] as String,
        sdpMap['type'] as String? ?? 'answer',
      );
      await _peerConnection!.setRemoteDescription(remoteDesc);
      _hasRemoteDescription = true;
      debugPrint('[WebRTC] Remote answer set. Flushing candidate queue...');
      await _drainCandidateQueue();
    } catch (e) {
      debugPrint('[WebRTC] Error setting remote answer: $e');
    }
  }

  /// Add incoming ICE candidate (or queue if remote description isn't ready)
  Future<void> addRemoteCandidate(Map<String, dynamic> candidateMap) async {
    final candidate = RTCIceCandidate(
      candidateMap['candidate'] as String?,
      candidateMap['sdpMid'] as String?,
      candidateMap['sdpMLineIndex'] is int
          ? candidateMap['sdpMLineIndex'] as int
          : int.tryParse(candidateMap['sdpMLineIndex']?.toString() ?? '0') ?? 0,
    );

    if (_hasRemoteDescription && _peerConnection != null) {
      try {
        await _peerConnection!.addCandidate(candidate);
        debugPrint('[WebRTC] Remote candidate added immediately.');
      } catch (e) {
        debugPrint('[WebRTC] Error adding remote candidate: $e');
      }
    } else {
      debugPrint(
        '[WebRTC] Queueing remote candidate (remoteDescription not set yet).',
      );
      _queuedRemoteCandidates.add(candidate);
    }
  }

  /// Drain queued ICE candidates
  Future<void> _drainCandidateQueue() async {
    if (_peerConnection == null) return;
    while (_queuedRemoteCandidates.isNotEmpty) {
      final c = _queuedRemoteCandidates.removeAt(0);
      try {
        await _peerConnection!.addCandidate(c);
        debugPrint('[WebRTC] Queued candidate flushed.');
      } catch (e) {
        debugPrint('[WebRTC] Error adding queued candidate: $e');
      }
    }
  }

  /// Trigger ICE Restart for network switch (WiFi <-> LTE) or connection failure.
  /// Returned offer ko caller Odoo ke notify_call_members se bheje.
  Future<RTCSessionDescription?> restartIce() async {
    if (_peerConnection == null) return null;
    try {
      final RTCSessionDescription description = await _peerConnection!
          .createOffer({'iceRestart': true});
      await _peerConnection!.setLocalDescription(description);
      debugPrint('[WebRTC] ICE restart offer generated.');
      return description;
    } catch (e) {
      debugPrint('[WebRTC] Error during ICE restart: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------

  /// Toggle Audio Mute
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        _isAudioMuted = !_isAudioMuted;
        audioTracks[0].enabled = !_isAudioMuted;
        debugPrint('[WebRTC] Audio muted: $_isAudioMuted');
        _dcSend('info', {
          'isSelfMuted': _isAudioMuted,
          'isRaisingHand': false,
          'isDeaf': false,
          'isTalking': false,
          'isCameraOn': !_isVideoOff,
          'isScreenSharingOn': false,
        });
      }
    }
  }

  /// Toggle Video Camera
  void toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        _isVideoOff = !_isVideoOff;
        videoTracks[0].enabled = !_isVideoOff;
        debugPrint('[WebRTC] Video off: $_isVideoOff');
      }
    }
  }

  /// Switch front/back camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks[0]);
        debugPrint('[WebRTC] Switched camera.');
      }
    }
  }

  /// Toggle Speakerphone / Earpiece
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    debugPrint('[WebRTC] Speakerphone enabled: $_isSpeakerOn');
  }

  /// Toggle Audio Mute (alias for toggleMute)
  void toggleAudioMute() => toggleMute();

  // ---------------------------------------------------------------------
  // Debug: audio/video bytes aa rahe hain ya nahi
  // ---------------------------------------------------------------------
  void _startStatsLogging() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) => logStats());
  }

  Future<void> logStats() async {
    final pc = _peerConnection;
    if (pc == null) return;
    final stats = await pc.getStats();
    for (final s in stats) {
      if (s.type == 'outbound-rtp' || s.type == 'inbound-rtp') {
        final kind = s.values['kind'] ?? s.values['mediaType'];
        final bytes = s.type == 'outbound-rtp'
            ? s.values['bytesSent']
            : s.values['bytesReceived'];
        debugPrint('[STATS] ${s.type} $kind bytes=$bytes');
      }
      if (s.type == 'candidate-pair' && s.values['state'] == 'succeeded') {
        debugPrint(
          '[STATS] pair succeeded rtt=${s.values['currentRoundTripTime']}',
        );
      }
    }
  }

  /// End call and dispose session
  Future<void> endCall() async => await dispose();

  /// Complete cleanup and resource disposal
  Future<void> dispose() async {
    debugPrint('[WebRTC] Disposing WebRTC session...');
    _statsTimer?.cancel();
    _statsTimer = null;
    _hasRemoteDescription = false;
    _queuedRemoteCandidates.clear();

    // Release wakelock
    await WakelockPlus.disable();

    await _dataChannel?.close();
    _dataChannel = null;

    // Stop local tracks
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    // Dispose remote stream
    await _remoteStream?.dispose();
    _remoteStream = null;

    // Close peer connection
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;

    // Reset renderers
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }
}
