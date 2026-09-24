import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/message_models.dart';
import '../data/messaging_repository.dart';

final conversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
  final auth = ref.watch(authProvider);
  final userId = auth.userId;
  final role = auth.role;
  if (userId == null || role == null) return const [];
  return ref.watch(messagingRepositoryProvider).fetchConversations(myUserId: userId, myRole: role);
});

/// One conversation's messages, kept live via `conversation-{id}` (Requirement
/// 1 §6.8) -- an initial fetch, then every new INSERT on `messages` for this
/// conversation_id is appended as it arrives. This is the app's first use of
/// Supabase Realtime, so the channel is opened/closed here rather than
/// through a shared helper -- nothing else needs this shape yet.
final conversationMessagesProvider = StreamProvider.autoDispose.family<List<Message>, String>((ref, conversationId) {
  final repo = ref.watch(messagingRepositoryProvider);
  final supabase = repo.supabase;
  final controller = StreamController<List<Message>>();
  var current = <Message>[];

  final channel = supabase.channel('conversation-$conversationId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
        callback: (payload) {
          final message = Message.fromMap(payload.newRecord);
          if (current.any((m) => m.id == message.id)) return;
          current = [...current, message];
          if (!controller.isClosed) controller.add(current);
        },
      )
      .subscribe();

  repo.fetchMessages(conversationId).then((messages) {
    current = messages;
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
