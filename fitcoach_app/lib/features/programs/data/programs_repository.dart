import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'program_models.dart';

/// Direct RLS-gated reads/writes on programs/program_habits (migration 023),
/// per CLAUDE.md's hybrid pattern -- a trainer building/publishing their own
/// program, and a client browsing the public marketplace listing, are both
/// simple RLS-gated operations (migration 023's programs_write/
/// programs_select policies), not the kind of cross-user transactional logic
/// that needs an Edge Function. Only *subscribing* (programs ->
/// program_subscriptions, across the trainer/client boundary, cascading into
/// workout_assignments/habits) goes through programs-api -- see
/// subscribe_program_repository.dart.
class ProgramsRepository {
  ProgramsRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _selectWithRelations =
      '*, trainer_profiles(display_name), workout_cards(id,title), program_habits(habit_templates(id,title,type,unit))';

  Future<List<Program>> fetchPublicPrograms() async {
    final rows = await _supabase
        .from('programs')
        .select(_selectWithRelations)
        .eq('is_published', true)
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((row) => Program.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<List<Program>> fetchTrainerPrograms(String trainerId) async {
    final rows = await _supabase
        .from('programs')
        .select(_selectWithRelations)
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((row) => Program.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<Program> fetchProgram(String programId) async {
    final row = await _supabase.from('programs').select(_selectWithRelations).eq('id', programId).single();
    return Program.fromMap(row);
  }

  Future<String> createProgram({
    required String trainerId,
    required String title,
    String? description,
    required num priceInr,
    required String billingPeriod,
    String? workoutCardId,
    required bool isPublished,
  }) async {
    final row = await _supabase
        .from('programs')
        .insert({
          'trainer_id': trainerId,
          'title': title,
          'description': description,
          'price_inr': priceInr,
          'billing_period': billingPeriod,
          'workout_card_id': workoutCardId,
          'is_published': isPublished,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateProgram({
    required String programId,
    required String title,
    String? description,
    required num priceInr,
    required String billingPeriod,
    String? workoutCardId,
    required bool isPublished,
  }) {
    return _supabase.from('programs').update({
      'title': title,
      'description': description,
      'price_inr': priceInr,
      'billing_period': billingPeriod,
      'workout_card_id': workoutCardId,
      'is_published': isPublished,
    }).eq('id', programId);
  }

  /// Whole-list replace (delete then insert), same pattern as
  /// WorkoutCardsRepository.replaceExercises -- the builder screen always
  /// sends the full current habit-template selection, not incremental
  /// adds/removes.
  Future<void> replaceProgramHabits(String programId, List<String> habitTemplateIds) async {
    await _supabase.from('program_habits').delete().eq('program_id', programId);
    if (habitTemplateIds.isEmpty) return;
    await _supabase.from('program_habits').insert([
      for (final habitTemplateId in habitTemplateIds) {'program_id': programId, 'habit_template_id': habitTemplateId},
    ]);
  }
}

final programsRepositoryProvider = Provider<ProgramsRepository>((ref) {
  return ProgramsRepository(ref.watch(supabaseClientProvider));
});
