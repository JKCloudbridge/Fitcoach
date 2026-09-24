import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/progress/utils/compute_weekly_adherence.dart';
import 'package:fitcoach_app/features/workout_logs/data/workout_log_models.dart';

WorkoutLog _log(DateTime logDate, String exerciseId) {
  return WorkoutLog(id: 'log-${logDate.day}-$exerciseId', clientId: 'client-1', assignmentExerciseId: exerciseId, logDate: logDate, createdAt: logDate);
}

void main() {
  group('computeWeeklyAdherence', () {
    final monday = DateTime(2026, 1, 5); // a Monday

    test('returns all zeros when there is no active assignment', () {
      expect(computeWeeklyAdherence([], monday, 0), List.filled(7, 0));
    });

    test('computes per-day fraction of distinct exercises logged', () {
      final logs = [
        _log(monday, 'ex1'),
        _log(monday, 'ex2'),
        _log(monday.add(const Duration(days: 1)), 'ex1'),
      ];
      final result = computeWeeklyAdherence(logs, monday, 2);
      expect(result[0], 1.0); // Monday: both exercises logged
      expect(result[1], 0.5); // Tuesday: one of two
      expect(result[2], 0.0); // Wednesday: none
    });

    test('does not double-count re-logging the same exercise twice in one day', () {
      final logs = [_log(monday, 'ex1'), _log(monday, 'ex1')];
      final result = computeWeeklyAdherence(logs, monday, 2);
      expect(result[0], 0.5);
    });

    test('clamps at 1.0 even if more distinct exercises are logged than exist', () {
      final logs = [_log(monday, 'ex1'), _log(monday, 'ex2'), _log(monday, 'ex3')];
      final result = computeWeeklyAdherence(logs, monday, 2);
      expect(result[0], 1.0);
    });
  });
}
