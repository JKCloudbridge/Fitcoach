import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'message_models.dart';

/// Direct RLS-gated reads/writes on conversations/conversation_members/messages
/// (migration 018) -- per §6.7, sending and reading a message within an
/// existing conversation is plain PostgREST, no Edge Function needed.
/// Starting a *new* conversation is the one exception (see
/// start_conversation_repository.dart).
class MessagingRepository {
  MessagingRepository(this._supabase);

  final SupabaseClient _supabase;

  SupabaseClient get supabase => _supabase;

  /// Composed client-side rather than one aggregation query: PostgREST can't
  /// cheaply express "latest message per conversation" through nested embeds
  /// across three tables, and at this app's expected conversation volume
  /// (one trainer's active roster, one client's coach(es)) three flat queries
  /// plus an in-memory reduce is simpler than a bespoke view or Edge Function
  /// for it -- same "don't over-build" call this project has made elsewhere
  /// (e.g. _TemplateBrowser's flat list).
  Future<List<ConversationSummary>> fetchConversations({required String myUserId, required String myRole}) async {
    final memberRows = await _supabase.from('conversation_members').select('conversation_id').eq('user_id', myUserId);
    final conversationIds = (memberRows as List).map((row) => (row as Map<String, dynamic>)['conversation_id'] as String).toList();
    if (conversationIds.isEmpty) return const [];

    final otherRows = await _supabase
        .from('conversation_members')
        .select('conversation_id, user_id')
        .inFilter('conversation_id', conversationIds)
        .neq('user_id', myUserId);
    final otherUserByConversation = <String, String>{
      for (final row in otherRows as List) (row as Map<String, dynamic>)['conversation_id'] as String: row['user_id'] as String,
    };

    final messageRows = await _supabase
        .from('messages')
        .select('conversation_id, sender_id, body, created_at, read_at')
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false);

    final lastByConversation = <String, Map<String, dynamic>>{};
    final unreadByConversation = <String, bool>{};
    for (final row in messageRows as List) {
      final map = row as Map<String, dynamic>;
      final conversationId = map['conversation_id'] as String;
      lastByConversation.putIfAbsent(conversationId, () => map);
      if (map['sender_id'] != myUserId && map['read_at'] == null) {
        unreadByConversation[conversationId] = true;
      }
    }

    // I'm a trainer -> the other member of a 1:1 conversation is always a
    // client (and vice versa) -- start_conversation() only ever pairs a
    // trainer with a client via an active coaching_relationships row, see
    // migration 018 -- so which profile table to read from is fixed by my
    // own role, not something that needs discovering per-conversation.
    final otherUserIds = otherUserByConversation.values.toSet().toList();
    final displayNames = await _fetchDisplayNames(otherUserIds, myRole: myRole);

    final summaries = <ConversationSummary>[
      for (final conversationId in conversationIds)
        if (otherUserByConversation[conversationId] case final otherUserId?)
          ConversationSummary(
            conversationId: conversationId,
            otherUserId: otherUserId,
            otherDisplayName: displayNames[otherUserId],
            lastMessageBody: lastByConversation[conversationId]?['body'] as String?,
            lastMessageAt: lastByConversation[conversationId] != null
                ? DateTime.parse(lastByConversation[conversationId]!['created_at'] as String)
                : null,
            lastMessageIsMine: lastByConversation[conversationId]?['sender_id'] == myUserId,
            hasUnread: unreadByConversation[conversationId] ?? false,
          ),
    ];
    summaries.sort((a, b) => (b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return summaries;
  }

  Future<Map<String, String?>> _fetchDisplayNames(List<String> userIds, {required String myRole}) async {
    if (userIds.isEmpty) return const {};
    final table = myRole == 'trainer' ? 'client_profiles' : 'trainer_profiles';
    final rows = await _supabase.from(table).select('id, display_name').inFilter('id', userIds);
    return {for (final row in rows as List) (row as Map<String, dynamic>)['id'] as String: row['display_name'] as String?};
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    final rows = await _supabase.from('messages').select().eq('conversation_id', conversationId).order('created_at');
    return (rows as List).map((row) => Message.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> sendMessage({required String conversationId, required String senderId, required String body}) {
    return _supabase.from('messages').insert({'conversation_id': conversationId, 'sender_id': senderId, 'body': body});
  }

  /// Marks every message in this conversation not sent by me as read --
  /// narrowed by migration 018's `grant update (read_at)`, so this can never
  /// touch body/sender_id even if the filter were wrong.
  Future<void> markConversationRead({required String conversationId, required String myUserId}) {
    return _supabase
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', myUserId)
        .isFilter('read_at', null);
  }
}

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(supabaseClientProvider));
});
