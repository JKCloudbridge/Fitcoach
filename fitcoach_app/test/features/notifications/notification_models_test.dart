import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/notifications/data/notification_models.dart';

void main() {
  group('AppNotification.fromMap', () {
    test('reads an unread card_assigned notification with its payload', () {
      final notification = AppNotification.fromMap({
        'id': 'notif-1',
        'type': 'card_assigned',
        'payload': {'assignment_id': 'assignment-1', 'card_id': 'card-1'},
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(notification.type, 'card_assigned');
      expect(notification.payload['card_id'], 'card-1');
      expect(notification.isUnread, isTrue);
    });

    test('reads a read message notification', () {
      final notification = AppNotification.fromMap({
        'id': 'notif-2',
        'type': 'message',
        'payload': {'conversation_id': 'conv-1'},
        'created_at': '2026-01-01T00:00:00Z',
        'read_at': '2026-01-01T00:05:00Z',
      });
      expect(notification.isUnread, isFalse);
    });

    test('defaults payload to empty map when missing', () {
      final notification = AppNotification.fromMap({
        'id': 'notif-3',
        'type': 'card_flagged',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(notification.payload, isEmpty);
    });
  });
}
