import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/program_models.dart';
import '../data/program_subscriptions_repository.dart';
import '../data/programs_repository.dart';

final publicProgramsProvider = FutureProvider.autoDispose<List<Program>>((ref) {
  return ref.watch(programsRepositoryProvider).fetchPublicPrograms();
});

final trainerProgramsProvider = FutureProvider.autoDispose<List<Program>>((ref) async {
  final trainerId = ref.watch(authProvider.select((s) => s.userId));
  if (trainerId == null) return const [];
  return ref.watch(programsRepositoryProvider).fetchTrainerPrograms(trainerId);
});

final programWithHabitsProvider = FutureProvider.autoDispose.family<Program, String>((ref, programId) {
  return ref.watch(programsRepositoryProvider).fetchProgram(programId);
});

final myProgramSubscriptionsProvider = FutureProvider.autoDispose<List<ProgramSubscription>>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return const [];
  return ref.watch(programSubscriptionsRepositoryProvider).fetchMySubscriptions(clientId);
});

/// Program ids the signed-in client currently has *active* access to --
/// drives the "Subscribed" state in Discover's Programs list and the detail
/// sheet's subscribe-button gating.
final myActiveProgramIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final subscriptions = await ref.watch(myProgramSubscriptionsProvider.future);
  return subscriptions.where((s) => s.status == 'active').map((s) => s.programId).toSet();
});
