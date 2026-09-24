import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'habit_template_models.dart';

/// Direct RLS-gated reads/writes on habit_templates, per CLAUDE.md's hybrid
/// backend pattern -- a trainer editing their own template is single-owner
/// CRUD (migration 014's `trainer_id = auth.uid()` write policy), same
/// precedent as WorkoutCardsRepository. Only *assigning* a template to a
/// client crosses the trainer/client boundary -- see
/// assign_habit_template_repository.dart.
class HabitTemplatesRepository {
  HabitTemplatesRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<HabitTemplate>> fetchTrainerTemplates(String trainerId) async {
    final rows = await _supabase.from('habit_templates').select().eq('trainer_id', trainerId).order('created_at', ascending: false);
    return (rows as List<dynamic>).map((row) => HabitTemplate.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<HabitTemplate> fetchTemplate(String templateId) async {
    final row = await _supabase.from('habit_templates').select().eq('id', templateId).single();
    return HabitTemplate.fromMap(row);
  }

  Future<String> createTemplate({
    required String trainerId,
    required String title,
    String? description,
    required String type,
    String? unit,
    num? defaultTargetValue,
    required String visibility,
    required bool isPublished,
  }) async {
    final row = await _supabase
        .from('habit_templates')
        .insert({
          'trainer_id': trainerId,
          'title': title,
          'description': description,
          'type': type,
          'unit': unit,
          'default_target_value': defaultTargetValue,
          'visibility': visibility,
          'is_published': isPublished,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateTemplate({
    required String templateId,
    required String title,
    String? description,
    required String type,
    String? unit,
    num? defaultTargetValue,
    required String visibility,
    required bool isPublished,
  }) {
    return _supabase.from('habit_templates').update({
      'title': title,
      'description': description,
      'type': type,
      'unit': unit,
      'default_target_value': defaultTargetValue,
      'visibility': visibility,
      'is_published': isPublished,
    }).eq('id', templateId);
  }
}

final habitTemplatesRepositoryProvider = Provider<HabitTemplatesRepository>((ref) {
  return HabitTemplatesRepository(ref.watch(supabaseClientProvider));
});
