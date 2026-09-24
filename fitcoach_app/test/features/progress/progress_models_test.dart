import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/progress/data/progress_models.dart';

void main() {
  group('WeightLogEntry.fromMap', () {
    test('reads the joined exercise name', () {
      final entry = WeightLogEntry.fromMap({
        'actual_weight_kg': 82.5,
        'log_date': '2026-02-03',
        'assignment_exercises': {'name': 'Back Squat'},
      });
      expect(entry.exerciseName, 'Back Squat');
      expect(entry.weightKg, 82.5);
    });

    test('falls back when the exercise join is missing', () {
      final entry = WeightLogEntry.fromMap({'actual_weight_kg': 50, 'log_date': '2026-02-03'});
      expect(entry.exerciseName, 'Exercise');
    });
  });
}
