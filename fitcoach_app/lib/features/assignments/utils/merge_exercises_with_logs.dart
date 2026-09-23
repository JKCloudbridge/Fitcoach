import '../../workout_logs/data/workout_log_models.dart';
import '../data/assignment_models.dart';

/// One assignment_exercise plus (if it exists) today's logged set for it.
/// "Done" is derived, not stored -- a plan repeats day to day, so whether
/// today's instance of an exercise is checked off depends on whether a
/// workout_logs row with today's log_date exists for it, per
/// Requirement 1 §3.10's own note that logging is date-scoped.
class TodayExerciseStatus {
  const TodayExerciseStatus({required this.exercise, this.log});

  final AssignmentExercise exercise;
  final WorkoutLog? log;

  bool get done => log != null;
}

/// Pure function (no Supabase/Dio) so it's unit-testable without mocking,
/// same convention as core/router/redirect_logic.dart's `resolveRedirect`.
/// `todayLogs` should already be filtered to today's log_date by the caller
/// (WorkoutLogsRepository.fetchTodayLogs does this) -- this function only
/// matches by assignment_exercise_id, it doesn't re-check the date itself.
List<TodayExerciseStatus> mergeExercisesWithLogs(List<AssignmentExercise> exercises, List<WorkoutLog> todayLogs) {
  final logsByExerciseId = {for (final log in todayLogs) log.assignmentExerciseId: log};
  return [for (final exercise in exercises) TodayExerciseStatus(exercise: exercise, log: logsByExerciseId[exercise.id])];
}
