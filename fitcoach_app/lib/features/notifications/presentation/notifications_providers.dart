import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../messaging/presentation/messaging_providers.dart';
import '../data/notification_models.dart';
import '../data/notifications_repository.dart';

/// A signed-in user's own notifications, kept live on a `notifications-{id}`
/// channel -- not one of the two channels Requirement 1 §6.8 names
/// explicitly (`conversation-{id}`/`assignment-{client_id}`), but the same
/// "per-user Realtime channel for personal Postgres changes" shape, applied
/// to the one other table (`notifications`) this milestone adds that needs
/// live updates. Same initial-fetch-then-append pattern as
/// conversationMessagesProvider.
final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return Stream.value(const []);

  final repo = ref.watch(notificationsRepositoryProvider);
  final supabase = repo.supabase;
  final controller = StreamController<List<AppNotification>>();
  var current = <AppNotification>[];

  final channel = supabase.channel('notifications-$userId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
        callback: (payload) {
          final notification = AppNotification.fromMap(payload.newRecord);
          current = [notification, ...current];
          if (!controller.isClosed) controller.add(current);
          // A new `message`-type notification means the conversation list's
          // preview/unread state is stale -- cheaper to just refetch it than
          // to also keep a live channel open on every conversation a user
          // isn't currently viewing.
          if (notification.type == 'message') {
            ref.invalidate(conversationsProvider);
          }
        },
      )
      .subscribe();

  repo.fetchNotifications(userId).then((notifications) {
    current = notifications;
    if (!controller.isClosed) controller.add(current);
  }).catchError((Object error, StackTrace stackTrace) {
    if (!controller.isClosed) controller.addError(error, stackTrace);
  });

  ref.onDispose(() {
    unawaited(supabase.removeChannel(channel));
    unawaited(controller.close());
  });

  return controller.stream;
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
    data: (notifications) => notifications.where((n) => n.isUnread).length,
    orElse: () => 0,
  );
});
