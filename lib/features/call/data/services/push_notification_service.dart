import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../firebase_options.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_constants.dart';
import '../models/call_model.dart';
import '../providers/call_provider.dart';
import 'call_signaling_service.dart';
import 'callkit_service.dart';

/// Top-level background message handler for FCM (wakes up the app from killed/terminated or background state)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push Background] FCM message received: ${message.data} | Notification: ${message.notification?.title}');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[Push Background] Firebase.initializeApp error: $e');
  }

  final data = message.data;
  final action = data['action'] as String? ?? data['type'] as String? ?? '';
  final callIdStr = data['call_id'] as String? ?? '';
  final callId = int.tryParse(callIdStr);

  // 1. Handle Incoming Call in Killed/Background State
  if (action == 'incoming' || action == 'call' || action == 'webrtc_call') {
    if (callId != null) {
      final callerName = data['caller_name'] as String? ?? 'Incoming Call';
      final callTypeStr = data['call_type'] as String? ?? 'audio';
      final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;

      await CallKitService.showIncomingCallStatic(
        callId: callId,
        callerName: callerName,
        callType: callType,
        avatar: data['avatar'] as String?,
      );
    }
    return;
  }

  // 2. Handle Call Cancellation/End in Killed/Background State
  if (action == 'cancel' || action == 'ended' || action == 'rejected') {
    if (callId != null) {
      await CallKitService.endCallStatic(callId);
      await NotificationService.instance.cancel(callId);
    }
    return;
  }

  // 3. Handle Chat Message Notification when App is Removed / Killed / in Background
  // This ensures: "aur agr app remove ho to bhi chat ka notifiction aye"
  final senderName = data['sender_name'] as String? ??
      data['title'] as String? ??
      message.notification?.title ??
      'New Message';
  final messageText = data['message'] as String? ??
      data['body'] as String? ??
      message.notification?.body ??
      'Sent you a message';

  final notifId = data['id'] != null
      ? (int.tryParse(data['id'].toString()) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000)
      : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

  // Initialize NotificationService in this background isolate if not yet done
  await NotificationService.instance.initialize();
  await NotificationService.instance.showChatNotification(
    id: notifId,
    title: senderName,
    body: messageText,
    payload: data.isNotEmpty ? data : {'title': senderName, 'body': messageText},
  );
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final signaling = ref.watch(callSignalingServiceProvider);
  return PushNotificationService(signaling);
});

class PushNotificationService {
  // ignore: unused_field
  final CallSignalingService _signaling;
  final DioClient _dioClient = DioClient.instance;
  bool _initialized = false;

  PushNotificationService(this._signaling);

  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) return;

    try {
      // 1. Ensure Firebase is initialized
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } catch (e) {
        debugPrint('[Push] Firebase.initializeApp() already initialized: $e');
      }

      final messaging = FirebaseMessaging.instance;

      // 2. Set presentation options for iOS foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Request Notification permissions
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[Push] Notification permission status: ${settings.authorizationStatus}');

      // 4. Retrieve FCM push token and register with backend
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('🔥 [FCM TOKEN] : $token');
        await StorageService.instance.saveFcmToken(token);
        await saveFcmTokenToDatabase(token);
      }

      // 5. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 [FCM TOKEN REFRESHED] : $newToken');
        await StorageService.instance.saveFcmToken(newToken);
        await saveFcmTokenToDatabase(newToken);
      });

      // 6. Handle Foreground FCM Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[Push Foreground] FCM message received: ${message.data}');
        final data = message.data;
        final action = data['action'] as String? ?? data['type'] as String? ?? '';
        final callIdStr = data['call_id'] as String? ?? '';
        final callId = int.tryParse(callIdStr);

        if (action == 'incoming' || action == 'call' || action == 'webrtc_call') {
          if (callId != null) {
            final callerName = data['caller_name'] as String? ?? 'Incoming Call';
            final callTypeStr = data['call_type'] as String? ?? 'audio';
            CallKitService.showIncomingCallStatic(
              callId: callId,
              callerName: callerName,
              callType: callTypeStr == 'video' ? CallType.video : CallType.audio,
              avatar: data['avatar'] as String?,
            );
          }
        } else if (action == 'cancel' || action == 'ended' || action == 'rejected') {
          if (callId != null) {
            CallKitService.endCallStatic(callId);
            NotificationService.instance.cancel(callId);
          }
        } else {
          // Foreground Chat Message: Display heads-up notification banner
          final senderName = data['sender_name'] as String? ??
              data['title'] as String? ??
              message.notification?.title ??
              'New Message';
          final messageText = data['message'] as String? ??
              data['body'] as String? ??
              message.notification?.body ??
              'Sent you a message';

          final notifId = data['id'] != null
              ? (int.tryParse(data['id'].toString()) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000)
              : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

          NotificationService.instance.showChatNotification(
            id: notifId,
            title: senderName,
            body: messageText,
            payload: data,
          );
        }
      });

      // 7. Handle Background Notification Tap (User tapped notification when app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[Push] Notification clicked from background: ${message.data}');
        NotificationService.handleNotificationPayload(message.data);
      });

      // 8. Handle Terminated / Killed State Launch (User opened app from killed state via notification)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[Push] App opened from killed state via notification: ${initialMessage.data}');
        NotificationService.handleNotificationPayload(initialMessage.data);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[Push] Error initializing PushNotificationService: $e');
    }
  }

  /// Send FCM token to backend database API (/api/save_fcm_token)
  Future<bool> saveFcmTokenToDatabase(String token) async {
    try {
      debugPrint('📤 [FCM] Sending token to database API (${ApiConstants.saveFcmToken}) ...');
      final response = await _dioClient.post(
        ApiConstants.saveFcmToken,
        data: {'fcm_token': token},
      );

      debugPrint('📥 [FCM] /api/save_fcm_token response: ${response.statusCode} => ${response.data}');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && (data['success'] == true || data['status'] == 'success')) {
          debugPrint('✅ [FCM] Token updated successfully in database: ${data['message']}');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ [FCM] Could not save token to database (may require user login): $e');
      return false;
    }
  }
}
