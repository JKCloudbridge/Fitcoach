import '../data/habit_models.dart';

/// One habit plus (if it exists) today's logged entry for it. Same "done is
/// derived, not stored" reasoning as assignments/utils/
/// merge_exercises_with_logs.dart's TodayExerciseStatus.
class TodayHabitStatus {
  const TodayHabitStatus({required this.habit, this.log});

  final Habit habit;
  final HabitLog? log;

  bool get done => log?.completed ?? false;
}

/// Pure function (no Supabase) so it's unit-testable without mocking, same
/// convention as merge_exercises_with_logs.dart. `todayLogs` should already
/// be filtered to today's log_date by the caller (HabitsRepository.
/// fetchTodayLogs does this) -- this function only matches by habit_id.
List<TodayHabitStatus> mergeHabitsWithLogs(List<Habit> habits, List<HabitLog> todayLogs) {
  final logsByHabitId = {for (final log in todayLogs) log.habitId: log};
  return [for (final habit in habits) TodayHabitStatus(habit: habit, log: logsByHabitId[habit.id])];
}
