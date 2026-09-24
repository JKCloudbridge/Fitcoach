import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/notification_models.dart';
import '../data/notifications_repository.dart';
import 'notifications_providers.dart';

const _typeLabels = {
  'card_assigned': 'A trainer assigned you a new card',
  'client_completed_workout': 'A client completed their plan',
  'card_flagged': 'One of your cards was reported',
  'message': 'New message',
};

/// Full notification list. Tapping a `message` notification marks it read
/// and opens that conversation; every other type is deep-link-free this
/// milestone (no per-type detail screen exists yet to jump to -- see
/// Milestone 6.md's known gaps) -- tapping one just marks it read in place.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _handleTap(BuildContext context, WidgetRef ref, AppNotification notification) async {
    if (notification.isUnread) {
      await ref.read(notificationsRepositoryProvider).markRead(notification.id);
    }
    if (notification.type != 'message') return;
    final conversationId = notification.payload['conversation_id'] as String?;
    if (conversationId == null || !context.mounted) return;
    final role = ref.read(authProvider).role;
    final basePath = role == 'trainer' ? '/trainer/messages' : '/client/coach';
    context.push('$basePath/$conversationId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final userId = ref.watch(authProvider.select((s) => s.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: userId == null ? null : () => ref.read(notificationsRepositoryProvider).markAllRead(userId),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load notifications: $error')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: Icon(notification.isUnread ? Icons.circle : Icons.circle_outlined, size: 10),
                title: Text(_typeLabels[notification.type] ?? notification.type),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(notification.createdAt)),
                onTap: () => _handleTap(context, ref, notification),
              );
            },
          );
        },
      ),
    );
  }
}
