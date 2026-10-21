import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/call_model.dart';
import '../models/ice_server_model.dart';

typedef OnIceCandidateCallback = void Function(RTCIceCandidate candidate);
typedef OnConnectionStateCallback = void Function(RTCPeerConnectionState state);
typedef OnTrackCallback = void Function(MediaStream stream);

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

  // ICE Candidate Queue (queue candidates until remote description is set)
  final List<RTCIceCandidate> _queuedRemoteCandidates = [];
  bool _hasRemoteDescription = false;

  OnIceCandidateCallback? onIceCandidate;
  OnConnectionStateCallback? onConnectionStateChange;
  OnTrackCallback? onRemoteStreamAdded;
  VoidCallback? onCallEnded;

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
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
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
  Future<bool> createPeerConnectionInstance(List<IceServerModel> iceServers) async {
    final Map<String, dynamic> configuration = {
      'iceServers': iceServers.map((s) => s.toMap()).toList(),
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
      _peerConnection = await createPeerConnection(configuration, loopbackConstraints);

      // Add local media tracks to peer connection
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          debugPrint('[WebRTC] Local ICE candidate generated: ${candidate.candidate}');
          onIceCandidate?.call(candidate);
        }
      };

      // Listen for remote tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          remoteRenderer.srcObject = _remoteStream;
          onRemoteStreamAdded?.call(_remoteStream!);
        }
      };

      // Listen for connection state changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC] PeerConnection state changed: $state');
        onConnectionStateChange?.call(state);

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          debugPrint('[WebRTC] Connection failed. Triggering ICE restart...');
          restartIce();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          onCallEnded?.call();
        }
      };

      return true;
    } catch (e) {
      debugPrint('[WebRTC] Error creating RTCPeerConnection: $e');
      return false;
    }
  }

  /// Create and set local SDP Offer
  Future<RTCSessionDescription?> createOffer() async {
    if (_peerConnection == null) return null;
    try {
      final RTCSessionDescription description = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(description);
      debugPrint('[WebRTC] Local offer set successfully.');
      return description;
    } catch (e) {
      debugPrint('[WebRTC] Error creating offer: $e');
      return null;
    }
  }

  /// Handle incoming remote SDP Offer and create Answer
  Future<RTCSessionDescription?> handleRemoteOfferAndCreateAnswer(Map<String, dynamic> sdpMap) async {
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

      final RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[WebRTC] Local answer set successfully.');
      return answer;
    } catch (e) {
      debugPrint('[WebRTC] Error handling remote offer and creating answer: $e');
      return null;
    }
  }

  /// Handle incoming remote SDP Answer
  Future<void> handleRemoteAnswer(Map<String, dynamic> sdpMap) async {
    if (_peerConnection == null) return;
    try {
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
      debugPrint('[WebRTC] Queueing remote candidate (remoteDescription not set yet).');
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

  /// Trigger ICE Restart for network switch (WiFi <-> LTE) or connection failure
  Future<RTCSessionDescription?> restartIce() async {
    if (_peerConnection == null) return null;
    try {
      final RTCSessionDescription description = await _peerConnection!.createOffer({
        'iceRestart': true,
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(description);
      debugPrint('[WebRTC] ICE restart offer generated.');
      return description;
    } catch (e) {
      debugPrint('[WebRTC] Error during ICE restart: $e');
      return null;
    }
  }

  /// Toggle Audio Mute
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        _isAudioMuted = !_isAudioMuted;
        audioTracks[0].enabled = !_isAudioMuted;
        debugPrint('[WebRTC] Audio muted: $_isAudioMuted');
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
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(_isSpeakerOn);
      });
    }
    debugPrint('[WebRTC] Speakerphone enabled: $_isSpeakerOn');
  }

  /// Complete cleanup and resource disposal
  Future<void> dispose() async {
    debugPrint('[WebRTC] Disposing WebRTC session...');
    _hasRemoteDescription = false;
    _queuedRemoteCandidates.clear();

    // Release wakelock
    await WakelockPlus.disable();

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
