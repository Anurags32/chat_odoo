import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/pages/splash_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/domain/models/api_user_model.dart';
import '../../features/home/presentation/pages/home_shell_screen.dart';
import '../../features/chat/presentation/pages/real_chat_screen.dart';
import '../../features/groups/presentation/pages/group_chat_screen.dart';
import '../../features/groups/domain/models/group_model.dart';
import '../../features/call/presentation/pages/audio_call_screen.dart';
import '../../features/call/presentation/pages/video_call_screen.dart';
import '../../features/call/presentation/pages/group_call_screen.dart';
import '../../features/call/presentation/pages/call_history_screen.dart';
import '../../features/call/data/models/call_model.dart';
import '../../features/call/presentation/pages/rtc_connection_screen.dart';
import '../../features/call/presentation/pages/rtc_debug_log_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String apiUsers = '/api-users'; // alias to home
  static const String chat = '/chat';
  static const String groupChat = '/group-chat';
  static const String audioCall = '/audio-call';
  static const String videoCall = '/video-call';
  static const String groupCall = '/group-call';
  static const String callHistory = '/call-history';
  static const String rtcConnect = '/rtc-connect';
  static const String rtcLogs = '/rtc-logs';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeShellScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      // Backward compatibility alias for apiUsers
      GoRoute(
        path: apiUsers,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeShellScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: chat,
        pageBuilder: (context, state) {
          final user = state.extra as ApiUserModel;
          return CustomTransitionPage(
            key: state.pageKey,
            child: RealChatScreen(user: user),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: groupChat,
        pageBuilder: (context, state) {
          final group = state.extra as GroupModel;
          return CustomTransitionPage(
            key: state.pageKey,
            child: GroupChatScreen(group: group),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: audioCall,
        pageBuilder: (context, state) => MaterialPage(
          child: AudioCallScreen(extra: state.extra as Map<String, dynamic>?),
        ),
      ),
      GoRoute(
        path: videoCall,
        pageBuilder: (context, state) => MaterialPage(
          child: VideoCallScreen(extra: state.extra as Map<String, dynamic>?),
        ),
      ),
      GoRoute(
        path: groupCall,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final channelName = extra['channel_name'] as String? ?? 'Group Conference';
          final callType = extra['call_type'] as CallType? ?? CallType.video;
          final members = (extra['members'] as List?)?.cast<String>() ?? <String>[];

          return MaterialPage(
            child: GroupCallScreen(
              channelName: channelName,
              callType: callType,
              initialMembers: members,
            ),
          );
        },
      ),
      GoRoute(
        path: callHistory,
        pageBuilder: (context, state) => const MaterialPage(
          child: CallHistoryScreen(),
        ),
      ),
      GoRoute(
        path: rtcConnect,
        pageBuilder: (context, state) => const MaterialPage(
          child: RtcConnectionScreen(),
        ),
      ),
      GoRoute(
        path: rtcLogs,
        pageBuilder: (context, state) => const MaterialPage(
          child: RtcDebugLogScreen(),
        ),
      ),
    ],
  );
}
