import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../workout_logs/data/workout_log_models.dart';
import '../../workout_logs/data/workout_logs_repository.dart';
import '../data/assignment_models.dart';
import '../data/assignments_repository.dart';

final activeAssignmentProvider = FutureProvider.autoDispose<(WorkoutAssignment, List<AssignmentExercise>)?>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return null;
  return ref.watch(assignmentsRepositoryProvider).fetchActiveAssignment(clientId);
});

final todayLogsProvider = FutureProvider.autoDispose<List<WorkoutLog>>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return const [];
  return ref.watch(workoutLogsRepositoryProvider).fetchTodayLogs(clientId);
});
