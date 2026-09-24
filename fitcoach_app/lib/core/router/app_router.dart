import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assignments/presentation/today_session_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/email_otp_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/habit_templates/presentation/build_habit_template_screen.dart';
import '../../features/habit_templates/presentation/trainer_build_screen.dart';
import '../../features/habit_templates/presentation/trainer_library_screen.dart';
import '../../features/messaging/presentation/conversation_thread_screen.dart';
import '../../features/messaging/presentation/conversations_list_screen.dart';
import '../../features/notifications/presentation/notification_bell.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/role_select_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/profile/presentation/client_profile_edit_screen.dart';
import '../../features/profile/presentation/client_profile_screen.dart';
import '../../features/profile/presentation/trainer_profile_edit_screen.dart';
import '../../features/profile/presentation/trainer_profile_screen.dart';
import '../../features/workout_cards/presentation/build_session_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../../shared/widgets/role_shell.dart';
import 'redirect_logic.dart';

/// Role-gated GoRouter shells, direct analog of Proximity's
/// organizer/rider split per Plan.md -- except neither sibling app actually
/// has a role-gated *shell* (Proximity's StatefulShellRoute is a single
/// buyer-only bottom nav; organizer/rider are plain pushed routes reached
/// from a menu, not separate shells), so the dual-shell structure here is
/// built fresh for FitCoach, following Proximity's *conventions*
/// (redirect-guard shape, refreshListenable bridge, context.go after
/// waitUntilLoggedIn) rather than copying a pattern that doesn't exist there.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      return resolveRedirect(isLoading: auth.isLoading, isLoggedIn: auth.isLoggedIn, role: auth.role, path: state.uri.path);
    },
    routes: [
      // '/' itself is never rendered -- the redirect above always sends it
      // somewhere else (login, role-select, or a shell root) once auth
      // state has resolved.
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),

      GoRoute(path: '/login', builder: (context, state) => LoginScreen(redirectTo: state.uri.queryParameters['redirect'])),
      GoRoute(
        path: '/login/verify-otp',
        builder: (context, state) {
          final args = state.extra! as EmailOtpScreenArgs;
          return EmailOtpScreen(email: args.email, redirectTo: args.redirectTo);
        },
      ),

      GoRoute(path: '/onboarding/role-select', builder: (context, state) => const RoleSelectScreen()),

      // Pushed from NotificationBell -- outside both shells since it's
      // reachable from either one.
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleShell(
          navigationShell: navigationShell,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.explore), label: 'Discover'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progress'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Coach'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/client', builder: (context, state) => const TodaySessionScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/client/discover', builder: (context, state) => const DiscoverScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/client/progress', builder: (context, state) => const ProgressScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/coach',
                builder: (context, state) => const ConversationsListScreen(title: 'Coach', basePath: '/client/coach'),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ConversationThreadScreen(conversationId: state.pathParameters['conversationId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/profile',
                builder: (context, state) => const ClientProfileScreen(),
                routes: [GoRoute(path: 'edit', builder: (context, state) => const ClientProfileEditScreen())],
              ),
            ],
          ),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleShell(
          navigationShell: navigationShell,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
            NavigationDestination(icon: Icon(Icons.fitness_center), label: 'My Cards'),
            NavigationDestination(icon: Icon(Icons.add_box), label: 'Build'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer',
                builder: (context, state) => const ComingSoonScreen(title: 'Clients', actions: [NotificationBell()]),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/cards',
                builder: (context, state) => const TrainerLibraryScreen(),
                routes: [
                  GoRoute(
                    path: ':cardId',
                    builder: (context, state) => BuildSessionScreen(cardId: state.pathParameters['cardId']),
                  ),
                  GoRoute(
                    path: 'templates/:templateId',
                    builder: (context, state) => BuildHabitTemplateScreen(templateId: state.pathParameters['templateId']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [GoRoute(path: '/trainer/build', builder: (context, state) => const TrainerBuildScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/messages',
                builder: (context, state) => const ConversationsListScreen(title: 'Messages', basePath: '/trainer/messages'),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ConversationThreadScreen(conversationId: state.pathParameters['conversationId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/profile',
                builder: (context, state) => const TrainerProfileScreen(),
                routes: [GoRoute(path: 'edit', builder: (context, state) => const TrainerProfileEditScreen())],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// GoRouter's `refreshListenable` wants a `ChangeNotifier`, not a `Stream` --
/// same bridge both sibling apps use to wire their auth StateNotifier's
/// stream into it.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
