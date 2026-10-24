import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_model.dart';
import '../services/odoo_api.dart';
import '../services/signaling_service.dart';
import '../services/rtc_call_service.dart';
import '../services/rtc_logger.dart';
import '../services/call_signaling_service.dart';
import '../services/webrtc_service.dart';
import '../../../chat/data/providers/chat_api_provider.dart';
import '../../../chat/data/services/chat_api_service.dart';
import '../../../../core/storage/storage_service.dart';

/// Odoo API Service Provider
final odooApiProvider = Provider<OdooApi>((ref) {
  return OdooApi();
});

/// Signaling Service Provider
final signalingServiceProvider = Provider<SignalingService>((ref) {
  final api = ref.watch(odooApiProvider);
  return SignalingService(api);
});

/// Central WebRTC Audio Call Service Provider
final rtcCallServiceProvider = ChangeNotifierProvider<RtcCallService>((ref) {
  final api = ref.watch(odooApiProvider);
  final signaling = ref.watch(signalingServiceProvider);
  final service = RtcCallService(
    odooApi: api,
    signalingService: signaling,
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// RTC Logger Provider
final rtcLoggerProvider = ChangeNotifierProvider<RtcLogger>((ref) {
  return RtcLogger.instance;
});

/// Legacy Providers (for existing custom call screens and services)
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

/// CallStateData representation
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
    this.isVideoOff = true,
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

/// Unified CallManagerNotifier connecting to RtcCallService
class CallManagerNotifier extends StateNotifier<CallStateData> {
  final RtcCallService _rtcService;
  final WebRtcService _webrtc;
  final ChatApiService _chatApi;

  CallManagerNotifier(this._rtcService, this._webrtc, this._chatApi) : super(CallStateData()) {
    _rtcService.addListener(_syncState);
  }

  void _syncState() {
    if (!mounted) return;

    CallState mappedStatus;
    switch (_rtcService.status) {
      case CallStatus.idle:
        mappedStatus = CallState.idle;
        break;
      case CallStatus.ringing:
        mappedStatus = CallState.ringing;
        break;
      case CallStatus.connecting:
        mappedStatus = CallState.connecting;
        break;
      case CallStatus.connected:
        mappedStatus = CallState.connected;
        break;
      case CallStatus.ended:
        mappedStatus = CallState.ended;
        break;
      case CallStatus.failed:
        mappedStatus = CallState.failed;
        break;
    }

    state = state.copyWith(
      status: mappedStatus,
      isMuted: _rtcService.isMuted,
      isVideoOff: _rtcService.isVideoOff,
      isSpeakerOn: _rtcService.isSpeakerOn,
      durationSeconds: _rtcService.callDuration,
    );
  }

  /// Start a 1-to-1 call on an Odoo Discuss channel
  Future<bool> startCall({
    int? channelId,
    required int calleePartnerId,
    String? calleeName,
    CallType callType = CallType.audio,
  }) async {
    int targetChannelId = channelId ?? 0;
    if (targetChannelId <= 0) {
      try {
        final res = await _chatApi.createChannel(partnerId: calleePartnerId);
        if (res.success && res.data != null) {
          targetChannelId = res.data!.channel.id;
        }
      } catch (e) {
        RtcLogger.instance.log(
          'Failed to resolve channel for partner $calleePartnerId: $e',
          tag: 'CALL',
        );
      }
    }
    if (targetChannelId <= 0) {
      targetChannelId = calleePartnerId;
    }

    final isVideo = callType == CallType.video;
    final success = await _rtcService.joinCall(
      channelId: targetChannelId,
      isVideo: isVideo,
    );
    if (!mounted) return success;

    if (success) {
      state = state.copyWith(
        activeCall: CallModel(
          id: targetChannelId,
          callType: callType,
          state: CallState.connecting,
          startTime: DateTime.now(),
          caller: CallParticipant(
            partnerId: _rtcService.selfSessionId ?? 1,
            name: 'Me',
          ),
          callee: CallParticipant(
            partnerId: calleePartnerId,
            name: calleeName ?? 'Contact #$calleePartnerId',
          ),
        ),
        status: CallState.connecting,
        isIncoming: false,
      );
    }
    return success;
  }

  Future<void> startAudioCall({
    int? channelId,
    required int partnerId,
    String? channelName,
  }) async {
    await startCall(
      channelId: channelId,
      calleePartnerId: partnerId,
      calleeName: channelName,
      callType: CallType.audio,
    );
  }

  void showIncomingCall({required int channelId, required String callerName}) {
    if (!mounted) return;
    state = state.copyWith(
      activeCall: CallModel(
        id: channelId,
        callType: CallType.audio,
        state: CallState.ringing,
        startTime: DateTime.now(),
        caller: CallParticipant(partnerId: 0, name: callerName),
        callee: CallParticipant(partnerId: 1, name: 'Me'),
      ),
      status: CallState.ringing,
      isIncoming: true,
    );
  }

  void setIncomingCallFromPush({
    required int callId,
    required String callerName,
    required CallType callType,
  }) {
    if (!mounted) return;
    state = state.copyWith(
      activeCall: CallModel(
        id: callId,
        callType: callType,
        state: CallState.ringing,
        startTime: DateTime.now(),
        caller: CallParticipant(partnerId: 0, name: callerName),
        callee: CallParticipant(partnerId: 1, name: 'Me'),
      ),
      status: CallState.ringing,
      isIncoming: true,
    );
  }

  void handleBusEvent(String eventName, Map<String, dynamic> payload) {
    if (eventName == 'incoming' || eventName == 'call') {
      final callId = int.tryParse(payload['call_id']?.toString() ?? '') ??
          int.tryParse(payload['channel_id']?.toString() ?? '') ??
          1;
      final callerName = payload['caller_name'] as String? ?? 'Incoming Call';
      showIncomingCall(channelId: callId, callerName: callerName);
    } else if (eventName == 'reject' || eventName == 'cancel' || eventName == 'end') {
      endCall();
    }
  }

  Future<bool> acceptCall() async {
    final channelId = state.activeCall?.id ?? _rtcService.channelId;
    if (channelId <= 0) return false;
    if (mounted) {
      state = state.copyWith(status: CallState.connecting);
    }
    final isVideo = state.activeCall?.callType == CallType.video;
    final success = await _rtcService.joinCall(
      channelId: channelId,
      isVideo: isVideo,
    );
    if (!mounted) return success;
    return success;
  }

  Future<void> rejectCall({String reason = 'rejected'}) async {
    if (state.activeCall != null) {
      final record = state.activeCall!.copyWith(
        state: CallState.rejected,
      );
      StorageService.instance.saveCallRecord(record.toJson());
    }
    await _rtcService.hangUp();
    if (!mounted) return;
    state = state.copyWith(status: CallState.rejected, clearActiveCall: true);
  }

  Future<void> cancelCall([int? callId]) async {
    if (state.activeCall != null) {
      final record = state.activeCall!.copyWith(
        state: CallState.cancelled,
      );
      StorageService.instance.saveCallRecord(record.toJson());
    }
    await _rtcService.hangUp();
    if (!mounted) return;
    state = state.copyWith(status: CallState.cancelled, clearActiveCall: true);
  }

  Future<void> endCall() async {
    if (state.activeCall != null) {
      final record = state.activeCall!.copyWith(
        state: CallState.ended,
        duration: _rtcService.callDuration,
      );
      StorageService.instance.saveCallRecord(record.toJson());
    }
    await _rtcService.hangUp();
    if (!mounted) return;
    state = state.copyWith(status: CallState.ended, clearActiveCall: true);
  }

  void toggleMute() {
    _rtcService.toggleMute();
  }

  Future<void> toggleSpeaker() async {
    await _rtcService.toggleSpeaker();
    if (!mounted) return;
    state = state.copyWith(isSpeakerOn: _rtcService.isSpeakerOn);
  }

  void toggleVideo() {
    _rtcService.toggleVideo();
    _webrtc.toggleVideo();
    if (!mounted) return;
    state = state.copyWith(isVideoOff: _rtcService.isVideoOff);
  }

  void switchCamera() {
    _rtcService.switchCamera();
    _webrtc.switchCamera();
  }

  void toggleScreenShare() {
    _rtcService.toggleScreenShare();
  }

  @override
  void dispose() {
    _rtcService.removeListener(_syncState);
    super.dispose();
  }
}

final callManagerProvider = StateNotifierProvider<CallManagerNotifier, CallStateData>((ref) {
  final rtcService = ref.read(rtcCallServiceProvider);
  final webrtc = ref.read(webrtcServiceProvider);
  final chatApi = ref.read(chatApiServiceProvider);
  return CallManagerNotifier(rtcService, webrtc, chatApi);
});
