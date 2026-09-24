import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/habit_templates/data/habit_template_models.dart';

void main() {
  group('HabitTemplate.fromMap', () {
    test('reads a published public quantity template with the joined trainer name', () {
      final template = HabitTemplate.fromMap({
        'id': 'template-1',
        'trainer_id': 'trainer-1',
        'title': 'Drink water',
        'type': 'quantity',
        'unit': 'glasses',
        'default_target_value': 8,
        'visibility': 'public',
        'is_published': true,
        'moderation_status': 'approved',
        'created_at': '2026-01-01T00:00:00Z',
        'trainer_profiles': {'display_name': 'Jordan Reyes'},
      });
      expect(template.trainerDisplayName, 'Jordan Reyes');
      expect(template.type, 'quantity');
      expect(template.defaultTargetValue, 8);
      expect(template.visibility, 'public');
      expect(template.isPublished, isTrue);
    });

    test('defaults missing optional fields', () {
      final template = HabitTemplate.fromMap({
        'id': 'template-1',
        'trainer_id': 'trainer-1',
        'title': 'Sleep 8 hours',
        'type': 'binary',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(template.visibility, 'private');
      expect(template.isPublished, isFalse);
      expect(template.moderationStatus, 'approved');
      expect(template.trainerDisplayName, isNull);
    });
  });
}
