import '../../workout_logs/data/workout_log_models.dart';

/// Monday..Sunday adherence fractions (0.0-1.0) for the week starting
/// `weekStart` (expected to be that week's Monday), against
/// `totalExercises` -- the active assignment's exercise count, constant
/// across the week per the snapshot pattern (assignment_exercises doesn't
/// change once assigned). A day's adherence is the count of distinct
/// assignment_exercise_ids logged that day divided by `totalExercises`.
/// Pure function (no Supabase) so it's unit-testable, same convention as
/// assignments/utils/merge_exercises_with_logs.dart. Returns 7 zeros when
/// there's no active assignment (`totalExercises == 0`).
List<double> computeWeeklyAdherence(List<WorkoutLog> logs, DateTime weekStart, int totalExercises) {
  if (totalExercises == 0) return List.filled(7, 0);

  final exerciseIdsByDay = <String, Set<String>>{};
  for (final log in logs) {
    final key = _dateOnly(log.logDate);
    exerciseIdsByDay.putIfAbsent(key, () => {}).add(log.assignmentExerciseId);
  }

  return [
    for (var i = 0; i < 7; i++)
      ((exerciseIdsByDay[_dateOnly(weekStart.add(Duration(days: i)))]?.length ?? 0) / totalExercises).clamp(0, 1),
  ];
}

String _dateOnly(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
