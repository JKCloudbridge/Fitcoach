import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/progress/data/progress_models.dart';
import 'package:fitcoach_app/features/progress/utils/find_personal_record.dart';

WeightLogEntry _entry(String name, num weightKg, DateTime logDate) {
  return WeightLogEntry(exerciseName: name, weightKg: weightKg, logDate: logDate);
}

void main() {
  group('findMostRecentPersonalRecord', () {
    test('returns null when there are no logs', () {
      expect(findMostRecentPersonalRecord([]), isNull);
    });

    test('picks the exercise whose max weight was logged most recently', () {
      final entries = [
        _entry('Back Squat', 80, DateTime(2026, 1, 1)),
        _entry('Back Squat', 82.5, DateTime(2026, 1, 15)),
        _entry('Bench Press', 60, DateTime(2026, 1, 10)),
      ];
      final record = findMostRecentPersonalRecord(entries);
      expect(record!.exerciseName, 'Back Squat');
      expect(record.weightKg, 82.5);
      expect(record.previousBestKg, 80);
      expect(record.deltaKg, 2.5);
    });

    test('deltaKg is null when there is only one weight logged for that exercise', () {
      final entries = [_entry('Deadlift', 100, DateTime(2026, 1, 1))];
      final record = findMostRecentPersonalRecord(entries);
      expect(record!.previousBestKg, isNull);
      expect(record.deltaKg, isNull);
    });

    test('a lower later log does not overwrite an earlier higher one as the PR', () {
      final entries = [
        _entry('Deadlift', 100, DateTime(2026, 1, 1)),
        _entry('Deadlift', 90, DateTime(2026, 1, 20)),
      ];
      final record = findMostRecentPersonalRecord(entries);
      expect(record!.weightKg, 100);
      // previousBestKg is "second-highest ever logged" for this exercise,
      // not "highest before the PR's date" -- with only two logs, that's
      // the 90kg one, even though it happened after the 100kg PR
      // chronologically (e.g. a deload day). A known simplification, not a
      // bug: see find_personal_record.dart's own doc comment.
      expect(record.previousBestKg, 90);
    });
  });
}
