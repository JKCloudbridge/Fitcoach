import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../habit_templates/data/habit_template_models.dart';
import '../data/habit_models.dart';
import '../data/habits_repository.dart';

final activeHabitsProvider = FutureProvider.autoDispose<List<Habit>>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return const [];
  return ref.watch(habitsRepositoryProvider).fetchActiveHabits(clientId);
});

final publicHabitTemplatesProvider = FutureProvider.autoDispose<List<HabitTemplate>>((ref) {
  return ref.watch(habitsRepositoryProvider).fetchPublicTemplates();
});

final todayHabitLogsProvider = FutureProvider.autoDispose<List<HabitLog>>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);
  if (habits.isEmpty) return const [];
  return ref.watch(habitsRepositoryProvider).fetchTodayLogs(habits.map((h) => h.id).toList());
});
