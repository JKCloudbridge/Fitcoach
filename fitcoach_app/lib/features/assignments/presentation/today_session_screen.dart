import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout_logs/presentation/log_set_sheet.dart';
import '../utils/merge_exercises_with_logs.dart';
import 'assignments_providers.dart';

/// Client "Today's session" -- the active assignment's exercises merged with
/// today's logs to show done/not-done, per the UI concept's screenToday().
/// Deliberately doesn't show the UI concept's wearable stat row (steps/HR) --
/// that data comes from `wearable_metrics`, which doesn't exist until
/// Milestone 5, so faking it here would misrepresent what's actually wired
/// up.
class TodaySessionScreen extends ConsumerWidget {
  const TodaySessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(activeAssignmentProvider);
    final logsAsync = ref.watch(todayLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: assignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your plan: $error')),
        data: (result) {
          if (result == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active plan yet — ask your trainer to assign one.', textAlign: TextAlign.center),
              ),
            );
          }
          final (assignment, exercises) = result;

          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Could not load today\'s progress: $error')),
            data: (todayLogs) {
              final statuses = mergeExercisesWithLogs(exercises, todayLogs);
              final doneCount = statuses.where((s) => s.done).length;

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(activeAssignmentProvider);
                  ref.invalidate(todayLogsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(assignment.cardTitle ?? 'Your plan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (assignment.trainerDisplayName != null) Text('from ${assignment.trainerDisplayName}'),
                    const SizedBox(height: 8),
                    Text('$doneCount of ${statuses.length} completed — tap an exercise to log it'),
                    const SizedBox(height: 16),
                    for (final status in statuses) _ExerciseTile(status: status),
                  ],
                ),
              );
            },
          );
        },
      ),
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
