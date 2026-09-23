import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'workout_card_models.dart';

/// Direct RLS-gated reads/writes on workout_cards/exercises, per CLAUDE.md's
/// hybrid backend pattern -- a trainer editing their own template is a
/// simple single-owner CRUD operation (migrations/006's `trainer_id =
/// auth.uid()` write policy), not the kind of cross-user transactional logic
/// that needs an Edge Function. Only *assigning* a card (workout_cards ->
/// workout_assignments, across the trainer/client boundary) goes through
/// workout-api -- see assign_workout_card_repository.dart.
class WorkoutCardsRepository {
  WorkoutCardsRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<WorkoutCard>> fetchTrainerCards(String trainerId) async {
    final rows = await _supabase
        .from('workout_cards')
        .select('*, exercises(id)')
        .eq('trainer_id', trainerId)
        .order('updated_at', ascending: false);
    return (rows as List<dynamic>).map((row) => WorkoutCard.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<(WorkoutCard, List<Exercise>)> fetchCardWithExercises(String cardId) async {
    final row = await _supabase.from('workout_cards').select('*, exercises(*)').eq('id', cardId).single();
    final exerciseRows = (row['exercises'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final exercises = exerciseRows.map(Exercise.fromMap).toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return (WorkoutCard.fromMap(row), exercises);
  }

  Future<String> createCard({
    required String trainerId,
    required String title,
    String? description,
    required String visibility,
    required String difficulty,
    required bool isPublished,
  }) async {
    final row = await _supabase
        .from('workout_cards')
        .insert({
          'trainer_id': trainerId,
          'title': title,
          'description': description,
          'visibility': visibility,
          'difficulty': difficulty,
          'is_published': isPublished,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateCard({
    required String cardId,
    required String title,
    String? description,
    required String visibility,
    required String difficulty,
    required bool isPublished,
  }) {
    return _supabase.from('workout_cards').update({
      'title': title,
      'description': description,
      'visibility': visibility,
      'difficulty': difficulty,
      'is_published': isPublished,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', cardId);
  }

  /// Whole-list replace (delete then insert), same pattern as Proximity's
  /// organizer feature's `replaceItems` -- the builder screen always sends
  /// the full current exercise list, not incremental adds/removes, so a
  /// clean replace is simpler and correct for a single-owner edit form.
  Future<void> replaceExercises(String cardId, List<Exercise> exercises) async {
    await _supabase.from('exercises').delete().eq('card_id', cardId);
    if (exercises.isEmpty) return;
    await _supabase.from('exercises').insert([
      for (var i = 0; i < exercises.length; i++) exercises[i].copyWith(orderIndex: i).toInsertMap(cardId),
    ]);
  }
}

final workoutCardsRepositoryProvider = Provider<WorkoutCardsRepository>((ref) {
  return WorkoutCardsRepository(ref.watch(supabaseClientProvider));
});
