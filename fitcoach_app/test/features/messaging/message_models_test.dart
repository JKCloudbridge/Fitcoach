import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/messaging/data/message_models.dart';

void main() {
  group('Message.fromMap', () {
    test('reads an unread message', () {
      final message = Message.fromMap({
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'sender_id': 'user-1',
        'body': 'Nice work on Tuesday\'s squats.',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(message.body, 'Nice work on Tuesday\'s squats.');
      expect(message.readAt, isNull);
    });

    test('reads a read message', () {
      final message = Message.fromMap({
        'id': 'msg-2',
        'conversation_id': 'conv-1',
        'sender_id': 'user-2',
        'body': 'Sounds good',
        'created_at': '2026-01-01T00:00:00Z',
        'read_at': '2026-01-01T00:05:00Z',
      });
      expect(message.readAt, DateTime.parse('2026-01-01T00:05:00Z'));
    });
  });
}
