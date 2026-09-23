import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/assignments/data/assignment_models.dart';
import 'package:fitcoach_app/features/assignments/utils/merge_exercises_with_logs.dart';
import 'package:fitcoach_app/features/workout_logs/data/workout_log_models.dart';

AssignmentExercise _exercise(String id, {int orderIndex = 0}) => AssignmentExercise(
  id: id,
  assignmentId: 'assignment-1',
  orderIndex: orderIndex,
  name: 'Exercise $id',
  sets: 3,
  reps: '10',
  restSeconds: 60,
);

WorkoutLog _log(String assignmentExerciseId) => WorkoutLog(
  id: 'log-$assignmentExerciseId',
  clientId: 'client-1',
  assignmentExerciseId: assignmentExerciseId,
  logDate: DateTime(2026, 1, 1),
  completed: true,
  createdAt: DateTime(2026, 1, 1, 9),
);

void main() {
  group('mergeExercisesWithLogs', () {
    test('marks an exercise done when a matching log exists', () {
      final result = mergeExercisesWithLogs([_exercise('ex-1'), _exercise('ex-2')], [_log('ex-1')]);
      expect(result[0].done, isTrue);
      expect(result[1].done, isFalse);
    });

    test('an exercise with no matching log is not done', () {
      final result = mergeExercisesWithLogs([_exercise('ex-1')], const []);
      expect(result.single.done, isFalse);
      expect(result.single.log, isNull);
    });

    test('a log for a different exercise id does not mark this one done', () {
      final result = mergeExercisesWithLogs([_exercise('ex-1')], [_log('ex-99')]);
      expect(result.single.done, isFalse);
    });

    test('preserves the input exercise order', () {
      final result = mergeExercisesWithLogs([_exercise('ex-2', orderIndex: 1), _exercise('ex-1', orderIndex: 0)], const []);
      expect(result.map((s) => s.exercise.id), ['ex-2', 'ex-1']);
    });
  });
}
