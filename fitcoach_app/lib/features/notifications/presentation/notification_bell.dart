import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'notifications_providers.dart';

/// AppBar action -- bell icon + unread-count badge, pushes the full
/// notifications list. Dropped into the AppBar of each shell's most-visited
/// screens (Today/Profile for the client shell, Clients/Profile for the
/// trainer shell, plus both Messages/Coach screens) rather than restructuring
/// every screen to share one persistent top bar -- see Milestone 6.md's scope
/// notes for why a shell-level app bar wasn't built for this.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
