import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/programs/data/program_models.dart';

void main() {
  group('Program.fromMap', () {
    test('reads a published paid program with joined trainer, card, and bundled habits', () {
      final program = Program.fromMap({
        'id': 'program-1',
        'trainer_id': 'trainer-1',
        'trainer_profiles': {'display_name': 'Jordan'},
        'title': '6-Week Strength Foundations',
        'description': 'Build a strength base.',
        'price_inr': 999,
        'billing_period': 'monthly',
        'workout_card_id': 'card-1',
        'workout_cards': {'id': 'card-1', 'title': 'Lower Body Strength'},
        'is_published': true,
        'moderation_status': 'approved',
        'created_at': '2026-01-01T00:00:00Z',
        'program_habits': [
          {
            'habit_templates': {'id': 'habit-1', 'title': 'Drink water', 'type': 'quantity', 'unit': 'glasses'},
          },
          {
            'habit_templates': {'id': 'habit-2', 'title': 'Sleep 8 hours', 'type': 'binary'},
          },
        ],
      });

      expect(program.isFree, isFalse);
      expect(program.trainerDisplayName, 'Jordan');
      expect(program.workoutCardTitle, 'Lower Body Strength');
      expect(program.habitTemplateIds, ['habit-1', 'habit-2']);
      expect(program.habitTemplateTitles, ['Drink water', 'Sleep 8 hours']);
    });

    test('defaults missing optional fields, including a habit-only program with no workout card', () {
      final program = Program.fromMap({
        'id': 'program-2',
        'trainer_id': 'trainer-1',
        'title': 'Habit Reset',
        'price_inr': 0,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(program.isFree, isTrue);
      expect(program.billingPeriod, 'one_time');
      expect(program.isPublished, isFalse);
      expect(program.workoutCardId, isNull);
      expect(program.workoutCardTitle, isNull);
      expect(program.habitTemplateIds, isEmpty);
      expect(program.habitTemplateTitles, isEmpty);
    });
  });

  group('ProgramSubscription.fromMap', () {
    test('reads an active subscription with the embedded program', () {
      final subscription = ProgramSubscription.fromMap({
        'id': 'sub-1',
        'client_id': 'client-1',
        'program_id': 'program-1',
        'status': 'active',
        'price_paid_inr': 999,
        'started_at': '2026-01-01T00:00:00Z',
        'current_period_end': '2026-02-01T00:00:00Z',
        'programs': {
          'id': 'program-1',
          'trainer_id': 'trainer-1',
          'title': '6-Week Strength Foundations',
          'price_inr': 999,
          'created_at': '2026-01-01T00:00:00Z',
        },
      });

      expect(subscription.status, 'active');
      expect(subscription.currentPeriodEnd, DateTime.parse('2026-02-01T00:00:00Z'));
      expect(subscription.program?.title, '6-Week Strength Foundations');
    });

    test('defaults missing optional fields when there is no embedded program', () {
      final subscription = ProgramSubscription.fromMap({
        'id': 'sub-2',
        'client_id': 'client-1',
        'program_id': 'program-2',
        'status': 'canceled',
        'price_paid_inr': 0,
        'started_at': '2026-01-01T00:00:00Z',
      });

      expect(subscription.currentPeriodEnd, isNull);
      expect(subscription.program, isNull);
    });
  });
}
