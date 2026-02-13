import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/pages/splash_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/users/presentation/pages/users_list_screen.dart';
import '../../features/chat/presentation/pages/chat_screen.dart';
import '../../features/chat/domain/models/user_model.dart';
import '../../features/groups/presentation/pages/groups_list_screen.dart';
import '../../features/groups/presentation/pages/group_chat_screen.dart';
import '../../features/groups/domain/models/group_model.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String usersList = '/users';
  static const String chat = '/chat';
  static const String groupsList = '/groups';
  static const String groupChat = '/group-chat';

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
        path: usersList,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const UsersListScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: chat,
        pageBuilder: (context, state) {
          final user = state.extra as UserModel;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatScreen(user: user),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          );
        },
      ),
      GoRoute(
        path: groupsList,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const GroupsListScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: groupChat,
        pageBuilder: (context, state) {
          final group = state.extra as GroupModel;
          return CustomTransitionPage(
            key: state.pageKey,
            child: GroupChatScreen(group: group),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          );
        },
      ),
    ],
  );
}
