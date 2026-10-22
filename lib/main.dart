import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/storage/storage_service.dart';
import 'core/services/notification_service.dart';

import 'features/call/presentation/pages/incoming_call_dialog.dart';
import 'features/call/data/services/callkit_service.dart';
import 'features/call/data/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Core
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] Initialization error: $e');
  }

  // 2. Register FCM Top-Level Background Message Handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3. Initialize Local Notifications Plugin & High-Importance Channels
  await NotificationService.instance.initialize();

  // 4. Initialize Local Key-Value Storage
  await StorageService.init();

  // 5. Set System UI Overlay Style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize CallKit, Push Notification listeners and handle launch from notification
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(callKitServiceProvider).initialize();
      ref.read(pushNotificationServiceProvider).initialize();
      await NotificationService.instance.checkAppLaunchNotification();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Norbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const IncomingCallDialog(),
          ],
        );
      },
    );
  }
}
