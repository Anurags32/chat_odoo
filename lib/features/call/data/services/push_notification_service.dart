import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_model.dart';
import 'call_signaling_service.dart';
import 'callkit_service.dart';
import '../providers/call_provider.dart';

/// Top-level background message handler for FCM (wakes up the app from killed/background)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push Background] FCM message received: ${message.data}');
  final data = message.data;
  final action = data['action'] as String? ?? '';
  final callIdStr = data['call_id'] as String? ?? '';
  final callId = int.tryParse(callIdStr);

  if (callId == null) return;

  if (action == 'incoming') {
    final callerName = data['caller_name'] as String? ?? 'Incoming Call';
    final callTypeStr = data['call_type'] as String? ?? 'audio';
    final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;

    await CallKitService.showIncomingCallStatic(
      callId: callId,
      callerName: callerName,
      callType: callType,
    );
  } else if (action == 'cancel' || action == 'ended' || action == 'rejected') {
    await CallKitService.endCallStatic(callId);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final signaling = ref.watch(callSignalingServiceProvider);
  return PushNotificationService(signaling);
});

class PushNotificationService {
  final CallSignalingService _signaling;
  bool _initialized = false;

  PushNotificationService(this._signaling);

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Initialize Firebase if available
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('[Push] Firebase.initializeApp() skipped or already initialized: $e');
      }

      // 2. Request Notification and VoIP permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[Push] Notification permission status: ${settings.authorizationStatus}');

      // 3. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Retrieve FCM push token
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[Push] FCM Device Token: $token');
        await _registerDeviceToken(token);
      }

      // 5. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[Push] FCM Token refreshed: $newToken');
        await _registerDeviceToken(newToken);
      });

      // 6. Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[Push Foreground] FCM message received: ${message.data}');
        final data = message.data;
        final action = data['action'] as String? ?? '';
        final callIdStr = data['call_id'] as String? ?? '';
        final callId = int.tryParse(callIdStr);

        if (callId == null) return;

        if (action == 'incoming') {
          final callerName = data['caller_name'] as String? ?? 'Incoming Call';
          final callTypeStr = data['call_type'] as String? ?? 'audio';
          CallKitService.showIncomingCallStatic(
            callId: callId,
            callerName: callerName,
            callType: callTypeStr == 'video' ? CallType.video : CallType.audio,
          );
        } else if (action == 'cancel' || action == 'ended' || action == 'rejected') {
          CallKitService.endCallStatic(callId);
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[Push] Error initializing PushNotificationService: $e');
    }
  }

  Future<void> _registerDeviceToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _signaling.registerDevice(
        platform: platform,
        fcmToken: token,
      );
      debugPrint('[Push] Registered $platform token with Odoo server.');
    } catch (e) {
      debugPrint('[Push] Failed to register device token with Odoo: $e');
    }
  }
}
