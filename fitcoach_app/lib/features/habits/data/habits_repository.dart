import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../habit_templates/data/habit_template_models.dart';
import 'habit_models.dart';

/// Direct RLS-gated reads/writes on habits/habit_logs (migrations 015-016:
/// `client_id = auth.uid()` / parent-habit ownership) -- self-created habit
/// tracking is single-owner data, no Edge Function needed, same precedent as
/// workout_logs. [adoptTemplate] included: unlike assign-workout-card, a
/// habit has no child snapshot table, so a client copying a *public*
/// template's fields into their own habit is still single-owner data, same
/// precedent as [createHabit] -- migration 015's RLS is what actually gates
/// which templates are adoptable (public/published/approved only). There is
/// deliberately no *trainer-push* method here -- that cross-user write is
/// Milestone 4.5's habits-api scope (see
/// habit_templates/data/assign_habit_template_repository.dart), not this
/// repository's, since it's the client acting for themselves either way.
class HabitsRepository {
  HabitsRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Habit>> fetchActiveHabits(String clientId) async {
    final rows = await _supabase.from('habits').select().eq('client_id', clientId).eq('status', 'active').order('created_at');
    return (rows as List<dynamic>).map((row) => Habit.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<List<HabitLog>> fetchTodayLogs(List<String> habitIds) async {
    if (habitIds.isEmpty) return const [];
    final today = _todayDateString();
    final rows = await _supabase.from('habit_logs').select().inFilter('habit_id', habitIds).eq('log_date', today);
    return (rows as List<dynamic>).map((row) => HabitLog.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> createHabit({
    required String clientId,
    required String title,
    required String type,
    String? unit,
    num? targetValue,
  }) {
    return _supabase.from('habits').insert({
      'client_id': clientId,
      'source': 'self_created',
      'title': title,
      'type': type,
      'unit': unit,
      'target_value': targetValue,
      'status': 'active',
    });
  }

  Future<List<HabitTemplate>> fetchPublicTemplates() async {
    final rows = await _supabase
        .from('habit_templates')
        .select('*, trainer_profiles(display_name)')
        .eq('visibility', 'public')
        .eq('is_published', true)
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((row) => HabitTemplate.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// Copies a public template's fields into a new self_created habit --
  /// `template_id` stays set (so it's traceable back to the template), but
  /// `source` stays `'self_created'` since the client is the one adopting
  /// it, not a trainer pushing it. Fields are copied as a starting point,
  /// not locked to the template -- the client owns this row afterward like
  /// any other self-created habit (can edit target/unit via updateHabit-
  /// style direct RLS, not built as a separate method since no UI calls it
  /// yet -- see Milestone 4.5.md's known gaps).
  Future<void> adoptTemplate({required String clientId, required HabitTemplate template}) {
    return _supabase.from('habits').insert({
      'template_id': template.id,
      'client_id': clientId,
      'source': 'self_created',
      'title': template.title,
      'type': template.type,
      'unit': template.unit,
      'target_value': template.defaultTargetValue,
      'wearable_metric_field': template.wearableMetricField,
      'status': 'active',
    });
  }

  /// Logs (or re-logs) today's entry for a habit. Unlike workout_logs'
  /// fetch-then-insert-or-update dance, habit_logs has a real unique
  /// (habit_id, log_date) constraint (migration 016), so this can upsert on
  /// it directly -- also fires the streak-recompute trigger, so the caller
  /// just needs to re-fetch today's logs afterward, not the habit itself.
  Future<void> logHabitToday({required String habitId, required bool completed, num? value}) {
    return _supabase.from('habit_logs').upsert({
      'habit_id': habitId,
      'log_date': _todayDateString(),
      'completed': completed,
      'value': value,
      'source': 'manual',
    }, onConflict: 'habit_id,log_date');
  }

  String _todayDateString() {
    final today = DateTime.now().toUtc();
    return '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }
}

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(ref.watch(supabaseClientProvider));
});
