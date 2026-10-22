import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call_model.dart';
import '../services/call_signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/callkit_service.dart';

final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService();
});

final webrtcServiceProvider = Provider<WebRtcService>((ref) {
  final service = WebRtcService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class CallStateData {
  final CallModel? activeCall;
  final CallState status;
  final bool isIncoming;
  final bool isMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;
  final int durationSeconds;
  final String? error;

  CallStateData({
    this.activeCall,
    this.status = CallState.idle,
    this.isIncoming = false,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isSpeakerOn = true,
    this.durationSeconds = 0,
    this.error,
  });

  CallStateData copyWith({
    CallModel? activeCall,
    CallState? status,
    bool? isIncoming,
    bool? isMuted,
    bool? isVideoOff,
    bool? isSpeakerOn,
    int? durationSeconds,
    String? error,
    bool clearActiveCall = false,
  }) {
    return CallStateData(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      status: status ?? this.status,
      isIncoming: isIncoming ?? this.isIncoming,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      error: error,
    );
  }
}

class CallManagerNotifier extends StateNotifier<CallStateData> {
  final CallSignalingService _signaling;
  final WebRtcService _webrtc;
  Timer? _durationTimer;

  CallManagerNotifier(this._signaling, this._webrtc) : super(CallStateData()) {
    _initWebRtcCallbacks();
  }

  void _initWebRtcCallbacks() {
    // When local ICE candidate is generated, send it to the peer
    _webrtc.onIceCandidate = (candidate) {
      if (state.activeCall != null) {
        _signaling.sendSignal(
          callId: state.activeCall!.id,
          type: 'candidate',
          payload: candidate.toMap(),
        );
      }
    };

    // When connection state changes
    _webrtc.onConnectionStateChange = (pcState) {
      debugPrint('[CallManager] PeerConnection State: $pcState');
      if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        state = state.copyWith(status: CallState.connected);
        _startDurationTimer();
      } else if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
        state = state.copyWith(status: CallState.connecting);
      } else if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        state = state.copyWith(error: 'Connection failed. Attempting reconnect...');
      } else if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          pcState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall();
      }
    };

    _webrtc.onCallEnded = () {
      endCall();
    };
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  // =========================================================================
  // Caller Actions
  // =========================================================================

  /// Start an outgoing audio or video call
  Future<bool> startCall({
    required int calleePartnerId,
    required CallType callType,
    String? calleeName,
  }) async {
    state = state.copyWith(status: CallState.ringing, isIncoming: false, durationSeconds: 0, error: null);

    await _webrtc.initRenderers();

    // 1. Acquire local microphone/camera stream
    final localStream = await _webrtc.startLocalStream(callType);
    if (localStream == null) {
      state = state.copyWith(status: CallState.idle, error: 'Could not access camera or microphone.');
      return false;
    }

    // 2. Fetch ICE servers (STUN/TURN)
    final iceServers = await _signaling.fetchIceServers();

    // 3. Create RTCPeerConnection
    final success = await _webrtc.createPeerConnectionInstance(iceServers);
    if (!success) {
      await _webrtc.dispose();
      state = state.copyWith(status: CallState.idle, error: 'Failed to initialize peer connection.');
      return false;
    }

    // 4. Contact Odoo to register call record and notify callee (with fallback)
    final call = await _signaling.startCall(
      calleePartnerId: calleePartnerId,
      callType: callType,
      calleeName: calleeName,
    );

    if (call == null) {
      await _webrtc.dispose();
      state = state.copyWith(status: CallState.idle, error: 'Failed to initiate call on server.');
      return false;
    }

    if (call.state == CallState.busy) {
      await _webrtc.dispose();
      state = state.copyWith(status: CallState.busy, error: 'User is currently busy on another call.');
      return false;
    }

    state = state.copyWith(activeCall: call, status: CallState.ringing);

    // 5. Generate SDP Offer and relay via bus (safe relay)
    try {
      final offer = await _webrtc.createOffer();
      if (offer != null) {
        await _signaling.sendSignal(
          callId: call.id,
          type: 'offer',
          payload: {'sdp': offer.sdp, 'type': offer.type},
        );
      }
    } catch (e) {
      debugPrint('[CallManager] Offer signalling relay note: $e');
    }

    return true;
  }


  // =========================================================================
  // Callee Actions
  // =========================================================================

  /// Called when an incoming call notification is received via WebSocket bus or Push
  void handleIncomingCall(CallModel call) {
    if (state.status != CallState.idle) {
      // Already in a call, reject as busy
      _signaling.rejectCall(call.id, reason: 'busy');
      return;
    }

    state = state.copyWith(
      activeCall: call,
      status: CallState.ringing,
      isIncoming: true,
      durationSeconds: 0,
      error: null,
    );

    // Also trigger native CallKit ringtone & notification
    CallKitService.showIncomingCallStatic(
      callId: call.id,
      callerName: call.caller.name,
      callType: call.callType,
      avatar: call.caller.avatarUrl,
    );
  }

  /// Sets up state if call was answered or received from FCM / CallKit push
  void setIncomingCallFromPush({
    required int callId,
    required String callerName,
    required CallType callType,
  }) {
    if (state.activeCall?.id == callId) return;
    final call = CallModel(
      id: callId,
      caller: CallParticipant(partnerId: 0, name: callerName),
      callee: CallParticipant(partnerId: 0, name: 'Me'),
      callType: callType,
      state: CallState.ringing,
      startTime: DateTime.now(),
    );
    state = state.copyWith(
      activeCall: call,
      status: CallState.ringing,
      isIncoming: true,
      durationSeconds: 0,
      error: null,
    );
  }

  /// Callee accepts the call
  Future<bool> acceptCall() async {
    final call = state.activeCall;
    if (call == null) return false;

    state = state.copyWith(status: CallState.connecting);

    await _webrtc.initRenderers();

    // 1. Acquire local stream
    final localStream = await _webrtc.startLocalStream(call.callType);
    if (localStream == null) {
      await rejectCall(reason: 'permission_denied');
      return false;
    }

    // 2. Fetch ICE servers
    final iceServers = await _signaling.fetchIceServers();

    // 3. Create PeerConnection
    await _webrtc.createPeerConnectionInstance(iceServers);

    // 4. Notify backend
    await _signaling.acceptCall(call.id);

    return true;
  }

  /// Callee rejects the call
  Future<void> rejectCall({String reason = 'rejected'}) async {
    final call = state.activeCall;
    if (call != null) {
      await _signaling.rejectCall(call.id, reason: reason);
    }
    await _cleanup();
    state = state.copyWith(status: CallState.rejected, clearActiveCall: true);
  }

  /// Caller cancels the call
  Future<void> cancelCall() async {
    final call = state.activeCall;
    if (call != null) {
      await _signaling.cancelCall(call.id);
    }
    await _cleanup();
    state = state.copyWith(status: CallState.cancelled, clearActiveCall: true);
  }

  /// Either peer ends the call
  Future<void> endCall({String reason = 'normal'}) async {
    final call = state.activeCall;
    if (call != null) {
      await _signaling.endCall(call.id, reason: reason);
    }
    await _cleanup();
    state = state.copyWith(status: CallState.ended, clearActiveCall: true);
  }

  // =========================================================================
  // WebRTC Bus Signaling Dispatcher
  // =========================================================================

  /// Handle incoming signal payload received from Odoo bus (offer, answer, candidate)
  Future<void> handleBusEvent(String event, dynamic payload) async {
    debugPrint('[CallManager] Handling bus event: $event | payload: $payload');

    switch (event) {
      case 'incoming_call':
        if (payload is Map && payload['call'] != null) {
          final call = CallModel.fromJson(payload['call'] as Map<String, dynamic>);
          handleIncomingCall(call);
        }
        break;

      case 'call_accepted':
        state = state.copyWith(status: CallState.connecting);
        break;

      case 'call_rejected':
        final reason = (payload is Map ? payload['reason'] : null) ?? 'rejected';
        await _cleanup();
        state = state.copyWith(
          status: reason == 'busy' ? CallState.busy : CallState.rejected,
          error: reason == 'busy' ? 'User is busy.' : 'Call declined.',
          clearActiveCall: true,
        );
        break;

      case 'call_cancelled':
        await _cleanup();
        state = state.copyWith(status: CallState.cancelled, error: 'Caller cancelled.', clearActiveCall: true);
        break;

      case 'call_ended':
        await _cleanup();
        state = state.copyWith(status: CallState.ended, clearActiveCall: true);
        break;

      case 'call_missed':
        await _cleanup();
        state = state.copyWith(status: CallState.missed, error: 'Call timed out.', clearActiveCall: true);
        break;

      case 'signal':
        if (payload is Map) {
          final type = payload['type'] as String?;
          final data = payload['payload'];

          if (type == 'offer' && data is Map) {
            final answer = await _webrtc.handleRemoteOfferAndCreateAnswer(Map<String, dynamic>.from(data));
            if (answer != null && state.activeCall != null) {
              await _signaling.sendSignal(
                callId: state.activeCall!.id,
                type: 'answer',
                payload: {'sdp': answer.sdp, 'type': answer.type},
              );
            }
          } else if (type == 'answer' && data is Map) {
            await _webrtc.handleRemoteAnswer(Map<String, dynamic>.from(data));
          } else if (type == 'candidate' && data is Map) {
            await _webrtc.addRemoteCandidate(Map<String, dynamic>.from(data));
          }
        }
        break;
    }
  }

  // =========================================================================
  // Media Controls
  // =========================================================================

  void toggleMute() {
    _webrtc.toggleMute();
    state = state.copyWith(isMuted: _webrtc.isAudioMuted);
  }

  void toggleVideo() {
    _webrtc.toggleVideo();
    state = state.copyWith(isVideoOff: _webrtc.isVideoOff);
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  void toggleSpeaker() {
    _webrtc.toggleSpeaker();
    state = state.copyWith(isSpeakerOn: _webrtc.isSpeakerOn);
  }

  Future<void> _cleanup() async {
    _stopDurationTimer();
    await _webrtc.dispose();
    await CallKitService.endAllCallsStatic();
  }

  @override
  void dispose() {
    _stopDurationTimer();
    super.dispose();
  }
}

final callManagerProvider = StateNotifierProvider<CallManagerNotifier, CallStateData>((ref) {
  final signaling = ref.watch(callSignalingServiceProvider);
  final webrtc = ref.watch(webrtcServiceProvider);
  return CallManagerNotifier(signaling, webrtc);
});
