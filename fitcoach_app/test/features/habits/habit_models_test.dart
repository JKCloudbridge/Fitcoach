import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/habits/data/habit_models.dart';

void main() {
  group('Habit.fromMap', () {
    test('reads a self-created quantity habit', () {
      final habit = Habit.fromMap({
        'id': 'habit-1',
        'client_id': 'client-1',
        'source': 'self_created',
        'title': 'Drink water',
        'type': 'quantity',
        'unit': 'glasses',
        'target_value': 8,
        'current_streak': 3,
        'best_streak': 5,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(habit.templateId, isNull);
      expect(habit.type, 'quantity');
      expect(habit.targetValue, 8);
      expect(habit.currentStreak, 3);
      expect(habit.bestStreak, 5);
    });

    test('defaults missing optional fields', () {
      final habit = Habit.fromMap({
        'id': 'habit-1',
        'client_id': 'client-1',
        'title': 'Sleep 8 hours',
        'type': 'binary',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(habit.source, 'self_created');
      expect(habit.status, 'active');
      expect(habit.currentStreak, 0);
      expect(habit.bestStreak, 0);
    });
  });

  group('HabitLog.fromMap', () {
    test('reads a completed manual log', () {
      final log = HabitLog.fromMap({
        'id': 'log-1',
        'habit_id': 'habit-1',
        'log_date': '2026-01-02',
        'value': 6,
        'completed': true,
        'source': 'manual',
        'created_at': '2026-01-02T08:00:00Z',
      });
      expect(log.habitId, 'habit-1');
      expect(log.value, 6);
      expect(log.completed, isTrue);
      expect(log.source, 'manual');
    });
  });
}
