import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../coaching/data/coaching_relationships_repository.dart';
import '../data/workout_card_models.dart';
import '../data/workout_cards_repository.dart';

final trainerCardsProvider = FutureProvider.autoDispose<List<WorkoutCard>>((ref) async {
  final trainerId = ref.watch(authProvider.select((s) => s.userId));
  if (trainerId == null) return const [];
  return ref.watch(workoutCardsRepositoryProvider).fetchTrainerCards(trainerId);
});

final cardWithExercisesProvider = FutureProvider.autoDispose.family<(WorkoutCard, List<Exercise>), String>((ref, cardId) {
  return ref.watch(workoutCardsRepositoryProvider).fetchCardWithExercises(cardId);
});

final trainerActiveClientsProvider = FutureProvider.autoDispose<List<CoachingClient>>((ref) async {
  final trainerId = ref.watch(authProvider.select((s) => s.userId));
  if (trainerId == null) return const [];
  return ref.watch(coachingRelationshipsRepositoryProvider).fetchActiveClients(trainerId);
});
