import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../habits/presentation/create_habit_sheet.dart';
import '../../habits/presentation/habits_providers.dart';
import 'progress_providers.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Client "Your progress" -- replaces `/client/progress`'s ComingSoonScreen.
/// Per the concept's `screenProgress()`, minus the steps/resting-HR/sleep
/// stat row it leans on (that's wearable_metrics, Milestone 5 -- not faked
/// here, same precedent TodaySessionScreen set in Milestone 2). Built from
/// what's actually derivable from existing tables: the weekly adherence
/// bars and the personal-record card both come from workout_logs/
/// assignment_exercises (Milestone 2), plus (Milestone 4, new) a habits
/// section with each active habit's streak -- per the user's own "Both"
/// answer, this is the streak/history half; the daily check-off half lives
/// on Today (habits/presentation/today_habits_section.dart).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weeklyAdherenceProvider);
          ref.invalidate(personalRecordProvider);
          ref.invalidate(activeHabitsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Last 7 days', style: TextStyle(fontSize: 13)),
            const Text('Your progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const _PersonalRecordCard(),
            const SizedBox(height: 20),
            Text('Weekly adherence', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _WeeklyAdherenceChart(),
            const SizedBox(height: 24),
            const _HabitsSection(),
          ],
        ),
      ),
    );
  }
}

class _PersonalRecordCard extends ConsumerWidget {
  const _PersonalRecordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(personalRecordProvider);
    return recordAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Text('Could not load personal records: $error'),
      data: (record) {
        if (record == null) return const SizedBox.shrink();
        final delta = record.deltaKg;
        return Card(
          color: AppColors.ink,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New personal record', style: TextStyle(color: AppColors.onInk, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${record.exerciseName} — ${record.weightKg}kg',
                      style: const TextStyle(color: AppColors.onInk, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 8),
                      Text('+${delta}kg', style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeeklyAdherenceChart extends ConsumerWidget {
  const _WeeklyAdherenceChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherenceAsync = ref.watch(weeklyAdherenceProvider);
    return adherenceAsync.when(
      loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Text('Could not load adherence: $error'),
      data: (adherence) {
        if (adherence.every((value) => value == 0)) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No active plan yet — adherence shows up once you have one.'),
          );
        }
        return SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: 1,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _weekdayLabels.length) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_weekdayLabels[index]));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < adherence.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: adherence[i], color: AppColors.lime, width: 18, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HabitsSection extends ConsumerWidget {
  const _HabitsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Habits', style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: () => showCreateHabitSheet(context), child: const Text('+ Add a habit')),
          ],
        ),
        habitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load habits: $error'),
          data: (habits) {
            if (habits.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No habits yet — add one to start building a streak.'),
              );
            }
            return Column(
              children: [
                for (final habit in habits)
                  Card(
                    child: ListTile(
                      title: Text(habit.title),
                      subtitle: Text(habit.bestStreak > 0 ? 'Best streak: ${habit.bestStreak} days' : 'No streak yet'),
                      trailing: habit.currentStreak > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, color: AppColors.coral, size: 18),
                                const SizedBox(width: 4),
                                Text('${habit.currentStreak}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
