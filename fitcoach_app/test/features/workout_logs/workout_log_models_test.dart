import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/workout_logs/data/workout_log_models.dart';

void main() {
  group('WorkoutLog.fromMap', () {
    test('reads populated fields', () {
      final log = WorkoutLog.fromMap({
        'id': 'log-1',
        'client_id': 'client-1',
        'assignment_exercise_id': 'ae-1',
        'log_date': '2026-01-01',
        'actual_sets': 4,
        'actual_reps': '6',
        'actual_weight_kg': 72.5,
        'completed': true,
        'perceived_effort': 7,
        'notes': 'Felt heavy',
        'created_at': '2026-01-01T09:00:00Z',
      });
      expect(log.actualSets, 4);
      expect(log.actualWeightKg, 72.5);
      expect(log.completed, isTrue);
      expect(log.perceivedEffort, 7);
    });

    test('defaults missing optional fields', () {
      final log = WorkoutLog.fromMap({
        'id': 'log-1',
        'client_id': 'client-1',
        'assignment_exercise_id': 'ae-1',
        'log_date': '2026-01-01',
        'created_at': '2026-01-01T09:00:00Z',
      });
      expect(log.completed, isFalse);
      expect(log.actualSets, isNull);
      expect(log.perceivedEffort, isNull);
    });
  });
}
