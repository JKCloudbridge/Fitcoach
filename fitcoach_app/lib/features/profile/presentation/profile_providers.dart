import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

final trainerProfileProvider = FutureProvider.autoDispose<TrainerProfile?>((ref) async {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchTrainerProfile(userId);
});

final clientProfileProvider = FutureProvider.autoDispose<ClientProfile?>((ref) async {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchClientProfile(userId);
});
