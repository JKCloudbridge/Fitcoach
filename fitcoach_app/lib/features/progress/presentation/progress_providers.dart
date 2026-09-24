import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/progress_repository.dart';
import '../utils/compute_weekly_adherence.dart';
import '../utils/find_personal_record.dart';

final weeklyAdherenceProvider = FutureProvider.autoDispose<List<double>>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return List.filled(7, 0);

  // Total exercises comes from the same active-assignment snapshot Today
  // already reads -- assignment_exercises doesn't change once assigned, so
  // it's a constant denominator across the whole week.
  final assignmentResult = await ref.watch(activeAssignmentProvider.future);
  final totalExercises = assignmentResult?.$2.length ?? 0;
  if (totalExercises == 0) return List.filled(7, 0);

  final weekStart = _mondayOf(DateTime.now());
  final logs = await ref.watch(progressRepositoryProvider).fetchLogsSince(clientId, weekStart);
  return computeWeeklyAdherence(logs, weekStart, totalExercises);
});

final personalRecordProvider = FutureProvider.autoDispose<PersonalRecord?>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return null;
  final entries = await ref.watch(progressRepositoryProvider).fetchWeightLogs(clientId);
  return findMostRecentPersonalRecord(entries);
});

DateTime _mondayOf(DateTime date) {
  final dateOnly = DateTime(date.year, date.month, date.day);
  return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
}
