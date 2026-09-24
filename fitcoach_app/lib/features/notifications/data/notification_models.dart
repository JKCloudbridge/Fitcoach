/// One row from `notifications` (migration 019), per Requirement 1 §3.20.
/// Always system-written -- see migration 019's four trigger functions for
/// where each `type` comes from.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type; // card_assigned | client_completed_workout | card_flagged | message
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'] as String,
    type: map['type'] as String,
    payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    createdAt: DateTime.parse(map['created_at'] as String),
    readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
  );
}
