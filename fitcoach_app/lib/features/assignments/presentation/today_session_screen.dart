import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/presentation/habits_providers.dart';
import '../../habits/presentation/today_habits_section.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../workout_logs/data/workout_log_models.dart';
import '../../workout_logs/presentation/log_set_sheet.dart';
import '../data/assignment_models.dart';
import '../utils/merge_exercises_with_logs.dart';
import 'assignments_providers.dart';

/// Client "Today's session" -- the active assignment's exercises merged with
/// today's logs to show done/not-done, per the UI concept's screenToday(),
/// plus (Milestone 4) a habit check-off list below it -- habits are tracked
/// independently of a workout plan, so that section renders even when there's
/// no active assignment. Deliberately doesn't show the UI concept's wearable
/// stat row (steps/HR) -- that data comes from `wearable_metrics`, which
/// doesn't exist until Milestone 5, so faking it here would misrepresent
/// what's actually wired up.
class TodaySessionScreen extends ConsumerWidget {
  const TodaySessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(activeAssignmentProvider);
    final logsAsync = ref.watch(todayLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today'), actions: const [NotificationBell()]),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeAssignmentProvider);
          ref.invalidate(todayLogsProvider);
          ref.invalidate(activeHabitsProvider);
          ref.invalidate(todayHabitLogsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WorkoutSection(assignmentAsync: assignmentAsync, logsAsync: logsAsync),
            const TodayHabitsSection(),
          ],
        ),
      ),
    );
  }
}

class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({required this.assignmentAsync, required this.logsAsync});

  final AsyncValue<(WorkoutAssignment, List<AssignmentExercise>)?> assignmentAsync;
  final AsyncValue<List<WorkoutLog>> logsAsync;

  @override
  Widget build(BuildContext context) {
    return assignmentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Could not load your plan: $error'),
      data: (result) {
        if (result == null) {
          return const Text('No active plan yet — ask your trainer to assign one.', textAlign: TextAlign.center);
        }
        final (assignment, exercises) = result;

        return logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load today\'s progress: $error'),
          data: (todayLogs) {
            final statuses = mergeExercisesWithLogs(exercises, todayLogs);
            final doneCount = statuses.where((s) => s.done).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.cardTitle ?? 'Your plan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (assignment.trainerDisplayName != null) Text('from ${assignment.trainerDisplayName}'),
                const SizedBox(height: 8),
                Text('$doneCount of ${statuses.length} completed — tap an exercise to log it'),
                const SizedBox(height: 16),
                for (final status in statuses) _ExerciseTile(status: status),
              ],
            );
          },
        );
      },
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.status});

  final TodayExerciseStatus status;

  @override
  Widget build(BuildContext context) {
    final exercise = status.exercise;
    final log = status.log;
    final subtitle = status.done
        ? 'Logged: ${log!.actualSets ?? exercise.sets} × ${log.actualReps ?? exercise.reps}'
        : '${exercise.sets} × ${exercise.reps}${exercise.weightKg != null ? ' @ ${exercise.weightKg}kg' : ''}';

    return Card(
      child: ListTile(
        leading: Icon(status.done ? Icons.check_circle : Icons.radio_button_unchecked, color: status.done ? Colors.green : null),
        title: Text(exercise.name, style: status.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
        subtitle: Text(subtitle),
        onTap: () => showLogSetSheet(context, exercise: exercise, existingLog: log),
      ),
    );
  }
}
