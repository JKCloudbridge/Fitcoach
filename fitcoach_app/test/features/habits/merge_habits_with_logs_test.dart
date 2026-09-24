import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/habits/data/habit_models.dart';
import 'package:fitcoach_app/features/habits/utils/merge_habits_with_logs.dart';

Habit _habit(String id, {String type = 'binary'}) {
  return Habit(id: id, clientId: 'client-1', title: id, type: type, createdAt: DateTime(2026, 1, 1));
}

HabitLog _log(String habitId, {bool completed = true, num? value}) {
  return HabitLog(id: '$habitId-log', habitId: habitId, logDate: DateTime(2026, 1, 2), completed: completed, value: value, createdAt: DateTime(2026, 1, 2));
}

void main() {
  group('mergeHabitsWithLogs', () {
    test('marks a habit done when a completed log exists for it', () {
      final result = mergeHabitsWithLogs([_habit('h1')], [_log('h1')]);
      expect(result.single.done, isTrue);
    });

    test('marks a habit not done when no log exists', () {
      final result = mergeHabitsWithLogs([_habit('h1')], []);
      expect(result.single.done, isFalse);
      expect(result.single.log, isNull);
    });

    test('marks a habit not done when its log is not completed', () {
      final result = mergeHabitsWithLogs([_habit('h1')], [_log('h1', completed: false)]);
      expect(result.single.done, isFalse);
    });

    test('matches logs to habits by habit_id, not list position', () {
      final result = mergeHabitsWithLogs([_habit('h1'), _habit('h2')], [_log('h2')]);
      expect(result[0].done, isFalse);
      expect(result[1].done, isTrue);
    });
  });
}
