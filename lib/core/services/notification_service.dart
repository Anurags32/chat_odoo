import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../router/app_router.dart';

/// Clean and reusable notification service for Foreground and Background/Killed notifications
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String chatChannelId = 'chat_messages';
  static const String chatChannelName = 'Chat Messages';
  static const String chatChannelDescription = 'Notifications for chat messages';

  static const String callChannelId = 'incoming_calls';
  static const String callChannelName = 'Incoming Calls';
  static const String callChannelDescription = 'Notifications for incoming calls';

  bool _isInitialized = false;

  /// Initialize local notifications plugin and channels
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (onNotificationTap != null) {
          onNotificationTap(response);
        } else {
          _handleNotificationTap(response);
        }
      },
    );

    // Create high importance Android notification channels
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Chat Channel with high importance for heads-up alerts
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          chatChannelId,
          chatChannelName,
          description: chatChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Call Channel with max importance for full screen / heads-up call rings
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          callChannelId,
          callChannelName,
          description: callChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Request runtime notification permission on Android 13+ (API 33+)
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint('[NotificationService] Local notifications and channels initialized.');
  }

  /// Display a heads-up Notification for incoming Chat messages
  Future<void> showChatNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      chatChannelId,
      chatChannelName,
      channelDescription: chatChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'New Chat Message',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  /// Display a high-priority Call Notification
  Future<void> showCallNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      callChannelId,
      callChannelName,
      channelDescription: callChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  /// Cancel all active notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Handle notification tap when user clicks notification
  static void _handleNotificationTap(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;

    try {
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      handleNotificationPayload(payload);
    } catch (e) {
      debugPrint('[NotificationService] Error handling payload: $e');
    }
  }

  /// Deep link navigation helper based on notification payload
  static void handleNotificationPayload(Map<String, dynamic> data) {
    debugPrint('[NotificationService] Navigating with payload: $data');
    final type = data['type'] as String? ?? data['action'] as String? ?? '';

    if (type == 'call' || type == 'incoming') {
      final callTypeStr = data['call_type'] as String? ?? 'audio';
      if (callTypeStr == 'video') {
        AppRouter.router.push(AppRouter.videoCall);
      } else {
        AppRouter.router.push(AppRouter.audioCall);
      }
    } else {
      // Default to chat/users
      AppRouter.router.push(AppRouter.apiUsers);
    }
  }

  /// Check if the app was cold-booted / opened by tapping a notification while terminated
  Future<void> checkAppLaunchNotification() async {
    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payloadStr = launchDetails.notificationResponse?.payload;
      if (payloadStr != null && payloadStr.isNotEmpty) {
        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          handleNotificationPayload(payload);
        } catch (e) {
          debugPrint('[NotificationService] Error parsing cold launch payload: $e');
        }
      }
    }
  }
}
