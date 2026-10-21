import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../models/call_model.dart';
import '../providers/call_provider.dart';

final callKitServiceProvider = Provider<CallKitService>((ref) {
  return CallKitService(ref);
});

class CallKitService {
  final Ref _ref;
  StreamSubscription? _eventSubscription;

  CallKitService(this._ref);

  void initialize() {
    _eventSubscription?.cancel();
    _eventSubscription = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      _handleCallKitEvent(event);
    });

    // Check if the app was launched by accepting a call from killed state
    checkPendingCall();
  }

  void dispose() {
    _eventSubscription?.cancel();
  }

  /// Show the native system incoming call UI (CallKit on iOS, Full-Screen Intent on Android)
  static Future<void> showIncomingCallStatic({
    required int callId,
    required String callerName,
    required CallType callType,
    String? avatar,
  }) async {
    final params = CallKitParams(
      id: callId.toString(),
      nameCaller: callerName,
      appName: 'Chat Odoo',
      avatar: avatar ?? '',
      handle: callerName,
      type: callType == CallType.video ? 1 : 0, // 0: audio, 1: video
      duration: 45000,
      extra: <String, dynamic>{
        'call_id': callId,
        'call_type': callType.toJson(),
        'caller_name': callerName,
      },
      headers: <String, dynamic>{'apiKey': '123#@'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#095544',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
        textAccept: 'Accept',
        textDecline: 'Decline',
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',
        isShowCallID: false,
        isShowFullLockedScreen: true,
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('[CallKit] Native incoming call UI displayed for Call ID $callId');
    } catch (e) {
      debugPrint('[CallKit] Error showing native call UI: $e');
    }
  }

  Future<void> showIncomingCall({
    required int callId,
    required String callerName,
    required CallType callType,
    String? avatar,
  }) => showIncomingCallStatic(
    callId: callId,
    callerName: callerName,
    callType: callType,
    avatar: avatar,
  );

  /// Dismiss the native CallKit / full screen UI
  static Future<void> endCallStatic(int callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId.toString());
      debugPrint('[CallKit] Dismissed Call ID $callId');
    } catch (e) {
      debugPrint('[CallKit] Error ending CallKit call: $e');
    }
  }

  Future<void> endCall(int callId) => endCallStatic(callId);

  /// Dismiss all active CallKit calls
  static Future<void> endAllCallsStatic() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] Error ending all calls: $e');
    }
  }

  Future<void> endAllCalls() => endAllCallsStatic();

  /// Check if the user launched or resumed the app by clicking 'Accept'
  Future<void> checkPendingCall() async {
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls.isNotEmpty) {
        final lastCall = activeCalls.last as Map<dynamic, dynamic>;
        final isAccepted = lastCall['isAccepted'] as bool? ?? false;
        final idStr = lastCall['id'] as String? ?? '';
        final callId = int.tryParse(idStr);

        if (isAccepted && callId != null) {
          debugPrint('[CallKit] Found pending accepted call: $callId. Resuming...');
          final extra = lastCall['extra'] as Map<dynamic, dynamic>? ?? {};
          final callTypeStr = extra['call_type'] as String? ?? 'audio';
          final callType = CallType.fromJson(callTypeStr);
          final callerName = extra['caller_name'] as String? ?? 'Caller';

          // Tell CallManagerNotifier to accept
          final callManager = _ref.read(callManagerProvider.notifier);
          callManager.setIncomingCallFromPush(
            callId: callId,
            callerName: callerName,
            callType: callType,
          );
          await callManager.acceptCall();

          // Navigate to call screen
          _navigateToCallScreen(callType);
        }
      }
    } catch (e) {
      debugPrint('[CallKit] Error checking pending calls: $e');
    }
  }

  void _handleCallKitEvent(CallEvent event) {
    debugPrint('[CallKit] Event: ${event.eventName}');

    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        final idStr = callKitParams.id;
        final callId = int.tryParse(idStr);
        if (callId != null) {
          final extra = callKitParams.extra ?? {};
          final callTypeStr = extra['call_type'] as String? ?? 'audio';
          final callType = CallType.fromJson(callTypeStr);
          final callerName = extra['caller_name'] as String? ?? 'Caller';

          final callManager = _ref.read(callManagerProvider.notifier);
          callManager.setIncomingCallFromPush(
            callId: callId,
            callerName: callerName,
            callType: callType,
          );
          callManager.acceptCall();

          _navigateToCallScreen(callType);
        }
        break;

      case CallEventActionCallDecline():
        _ref.read(callManagerProvider.notifier).rejectCall(reason: 'rejected');
        break;

      case CallEventActionCallEnded():
        _ref.read(callManagerProvider.notifier).endCall();
        break;

      case CallEventActionCallTimeout():
        _ref.read(callManagerProvider.notifier).endCall();
        break;

      default:
        break;
    }
  }

  void _navigateToCallScreen(CallType callType) {
    final route = callType == CallType.video ? '/video-call' : '/audio-call';
    AppRouter.router.push(route);
  }
}
