/// One row from `messages` (migration 018), per Requirement 1 §3.17-3.19.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id'] as String,
    conversationId: map['conversation_id'] as String,
    senderId: map['sender_id'] as String,
    body: map['body'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
  );
}

/// A row for the conversation list -- composed client-side from
/// conversation_members + messages + the counterpart's profile, rather than
/// one aggregation endpoint. 1:1 only this milestone (see migration 018's
/// header note), so "the other member" is always exactly one person.
class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.otherUserId,
    this.otherDisplayName,
    this.lastMessageBody,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.hasUnread = false,
  });

  final String conversationId;
  final String otherUserId;
  final String? otherDisplayName;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final bool hasUnread;
}
