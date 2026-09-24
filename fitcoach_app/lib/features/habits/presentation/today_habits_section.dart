import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/habit_models.dart';
import '../data/habits_repository.dart';
import '../utils/merge_habits_with_logs.dart';
import 'habits_providers.dart';

/// Embedded in TodaySessionScreen, below the workout exercises -- per the
/// user's own "Both" answer when asked where habit tracking should live: a
/// daily check-off list here, full streak/history on the Progress screen.
/// Renders nothing at all once a client has no active habits yet -- habit
/// *creation* lives on Progress (create_habit_sheet.dart), not here, so an
/// empty state here would just point at a button that doesn't exist on this
/// screen. Not shown in the concept HTML's screenToday() at all (see
/// Milestone 4.md's known-gaps section -- there's no habit UI anywhere in
/// the concept to build from).
class TodayHabitsSection extends ConsumerWidget {
  const TodayHabitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);

    return habitsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text('Could not load habits: $error'),
      ),
      data: (habits) {
        if (habits.isEmpty) return const SizedBox.shrink();

        final logsAsync = ref.watch(todayHabitLogsProvider);
        return logsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('Could not load today\'s habits: $error'),
          ),
          data: (todayLogs) {
            final statuses = mergeHabitsWithLogs(habits, todayLogs);
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s habits', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final status in statuses) _HabitCheckRow(status: status),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HabitCheckRow extends ConsumerWidget {
  const _HabitCheckRow({required this.status});

  final TodayHabitStatus status;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final habit = status.habit;
    if (habit.type == 'quantity') {
      final value = await showDialog<num>(
        context: context,
        builder: (context) => _HabitValueDialog(habit: habit, initialValue: status.log?.value),
      );
      if (value == null) return;
      final target = habit.targetValue;
      await ref.read(habitsRepositoryProvider).logHabitToday(
        habitId: habit.id,
        completed: target == null || value >= target,
        value: value,
      );
    } else {
      await ref.read(habitsRepositoryProvider).logHabitToday(habitId: habit.id, completed: !status.done);
    }
    ref.invalidate(todayHabitLogsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = status.habit;
    final subtitle = habit.type == 'quantity'
        ? (status.log?.value != null
              ? '${status.log!.value}${habit.unit != null ? ' ${habit.unit}' : ''}${habit.targetValue != null ? ' of ${habit.targetValue}' : ''}'
              : habit.targetValue != null
              ? 'Target: ${habit.targetValue}${habit.unit != null ? ' ${habit.unit}' : ''}'
              : null)
        : null;

    return Card(
      child: ListTile(
        leading: Icon(status.done ? Icons.check_circle : Icons.radio_button_unchecked, color: status.done ? Colors.green : null),
        title: Text(habit.title, style: status.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
        subtitle: subtitle != null ? Text(subtitle) : null,
        onTap: () => _onTap(context, ref),
      ),
    );
  }
}

class _HabitValueDialog extends StatefulWidget {
  const _HabitValueDialog({required this.habit, this.initialValue});

  final Habit habit;
  final num? initialValue;

  @override
  State<_HabitValueDialog> createState() => _HabitValueDialogState();
}

class _HabitValueDialogState extends State<_HabitValueDialog> {
  late final _controller = TextEditingController(text: widget.initialValue?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.habit.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: widget.habit.unit ?? 'Value', border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(num.tryParse(_controller.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
