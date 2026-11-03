import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/app_router.dart';

/// Top-level entry point for background notification responses (Inline Direct Reply & Mark as Read)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  debugPrint(
    '[NotificationService] Background action: ${response.actionId} | input: ${response.input}',
  );

  if (response.actionId == NotificationService.actionReply) {
    final replyText = response.input;
    if (replyText != null && replyText.trim().isNotEmpty) {
      await NotificationService.sendDirectReply(
        payloadStr: response.payload,
        replyText: replyText.trim(),
        notificationId: response.id ?? 0,
      );
    }
  } else if (response.actionId == NotificationService.actionMarkRead) {
    if (response.id != null) {
      await NotificationService.instance.cancel(response.id!);
    }
  }
}

/// WhatsApp-style Notification Service handling Heads-Up Notifications, RemoteInput Inline Replies,
/// rich sender previews, and deep-link navigation.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String chatChannelId = 'chat_messages';
  static const String chatChannelName = 'Chat Messages';
  static const String chatChannelDescription =
      'Notifications for chat messages';

  static const String callChannelId = 'incoming_calls';
  static const String callChannelName = 'Incoming Calls';
  static const String callChannelDescription =
      'Notifications for incoming calls';

  static const String actionReply = 'reply_action';
  static const String actionMarkRead = 'mark_read_action';

  bool _isInitialized = false;

  /// Initialize local notifications plugin, notification channels, and category actions
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // Darwin / iOS notification actions & categories
    final darwinNotificationCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        'chat_messages',
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.text(
            actionReply,
            'Reply',
            buttonTitle: 'Send',
            placeholder: 'Type a message...',
          ),
          DarwinNotificationAction.plain(
            actionMarkRead,
            'Mark as read',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.destructive,
            },
          ),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
    ];

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: darwinNotificationCategories,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == actionReply) {
          final replyText = response.input;
          if (replyText != null && replyText.trim().isNotEmpty) {
            sendDirectReply(
              payloadStr: response.payload,
              replyText: replyText.trim(),
              notificationId: response.id ?? 0,
            );
            return;
          }
        } else if (response.actionId == actionMarkRead) {
          if (response.id != null) {
            cancel(response.id!);
          }
          return;
        }

        if (onNotificationTap != null) {
          onNotificationTap(response);
        } else {
          _handleNotificationTap(response);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create high importance Android notification channels
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          chatChannelId,
          chatChannelName,
          description: chatChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          callChannelId,
          callChannelName,
          description: callChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint(
      '[NotificationService] Local notifications and inline reply actions initialized.',
    );
  }

  /// Display a WhatsApp-style Notification for incoming Chat messages with Inline Reply RemoteInput
  Future<void> showChatNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? avatarBase64,
    String? groupName,
    int unreadCount = 1,
  }) async {
    ByteArrayAndroidBitmap? largeIconBitmap;
    ByteArrayAndroidIcon? personIcon;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        final cleanBase64 = avatarBase64.contains(',')
            ? avatarBase64.split(',').last
            : avatarBase64;
        largeIconBitmap = ByteArrayAndroidBitmap.fromBase64String(cleanBase64);
        personIcon = ByteArrayAndroidIcon.fromBase64String(cleanBase64);
      } catch (_) {}
    }

    final person = Person(
      name: title,
      key: payload?['partner_id']?.toString() ?? title,
      icon: personIcon,
    );

    final messagingStyle = MessagingStyleInformation(
      person,
      conversationTitle: groupName,
      groupConversation: groupName != null && groupName.isNotEmpty,
      messages: [Message(body, DateTime.now(), person)],
    );

    final androidActions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        actionReply,
        'Reply',
        inputs: [AndroidNotificationActionInput(label: 'Type a message...')],
        allowGeneratedReplies: true,
        showsUserInterface: false,
      ),
      const AndroidNotificationAction(
        actionMarkRead,
        'Mark as read',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

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
      styleInformation: messagingStyle,
      largeIcon: largeIconBitmap,
      actions: androidActions,
      number: unreadCount,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'chat_messages',
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

  /// Send direct inline reply to Odoo backend via background HTTP execution
  static Future<void> sendDirectReply({
    required String? payloadStr,
    required String replyText,
    required int notificationId,
  }) async {
    if (payloadStr == null || payloadStr.isEmpty) return;

    try {
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final rawChannelId = payload['channel_id'] ?? payload['channelId'];
      final channelId = int.tryParse(rawChannelId?.toString() ?? '');
      final isGroup = payload['is_group'] == true || payload['type'] == 'group';
      final senderName =
          payload['sender_name'] ??
          payload['name'] ??
          payload['title'] ??
          'Chat';

      if (channelId == null || channelId <= 0) {
        debugPrint(
          '[NotificationService] Direct reply failed: missing channel_id',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');
      final sessionCookie = prefs.getString('session_cookie');
      final serverUrl =
          prefs.getString('odoo_server_url') ??
          'https://sanitizer-marsupial-delegator.ngrok-free.dev';

      final endpoint = isGroup
          ? '$serverUrl/api/chat/group/send'
          : '$serverUrl/api/chat/send';

      final requestData = jsonEncode({
        'channel_id': channelId,
        'body': replyText,
      });

      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        request.headers.set('Cookie', 'session_id=$sessionCookie');
      }
      request.add(utf8.encode(requestData));

      final response = await request.close();
      debugPrint(
        '[NotificationService] Direct reply HTTP response: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        // Confirmation notification to reassure the user
        await instance.showChatNotification(
          id: notificationId,
          title: senderName.toString(),
          body: '✓ Replied: $replyText',
          payload: payload,
        );
      }
      client.close();
    } catch (e) {
      debugPrint('[NotificationService] Error sending direct reply: $e');
    }
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

  /// Deep link navigation directly into the target chat or call screen
  static void handleNotificationPayload(Map<String, dynamic> data) {
    debugPrint('[NotificationService] Navigating with payload: $data');
    final type = (data['type'] ?? data['action'] ?? '')
        .toString()
        .toLowerCase();

    // 1. Call routes
    if (type == 'call' || type == 'incoming' || type == 'webrtc_call') {
      final callTypeStr = (data['call_type'] ?? 'audio')
          .toString()
          .toLowerCase();
      if (callTypeStr == 'video') {
        AppRouter.router.push(AppRouter.videoCall, extra: data);
      } else {
        AppRouter.router.push(AppRouter.audioCall, extra: data);
      }
      return;
    }

    // 2. Group Chat route
    final isGroup =
        data['is_group'] == true ||
        data['is_group'] == 'true' ||
        type == 'group' ||
        data.containsKey('group_name');

    if (isGroup) {
      AppRouter.router.push(AppRouter.groupChat, extra: data);
      return;
    }

    // 3. Direct Chat route
    final channelId = data['channel_id'] ?? data['channelId'];
    final partnerId =
        data['partner_id'] ?? data['partnerId'] ?? data['sender_id'];
    if (channelId != null || partnerId != null) {
      AppRouter.router.push(AppRouter.chat, extra: data);
      return;
    }

    // Fallback to Home
    AppRouter.router.push(AppRouter.home);
  }

  /// Check if the app was cold-booted / opened by tapping a notification while terminated
  Future<void> checkAppLaunchNotification() async {
    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payloadStr = launchDetails.notificationResponse?.payload;
      if (payloadStr != null && payloadStr.isNotEmpty) {
        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          // Allow router to initialize before pushing
          Future.delayed(const Duration(milliseconds: 300), () {
            handleNotificationPayload(payload);
          });
        } catch (e) {
          debugPrint(
            '[NotificationService] Error parsing cold launch payload: $e',
          );
        }
      }
    }
  }
}
