import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'workout_log_models.dart';

/// Direct RLS-gated reads/writes on workout_logs (migration 008:
/// `client_id = auth.uid()` write policy) -- a client logging their own set
/// is a simple single-owner write, no Edge Function needed.
class WorkoutLogsRepository {
  WorkoutLogsRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<WorkoutLog>> fetchTodayLogs(String clientId) async {
    final today = DateTime.now().toUtc();
    final dateOnly = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final rows = await _supabase.from('workout_logs').select().eq('client_id', clientId).eq('log_date', dateOnly);
    return (rows as List<dynamic>).map((row) => WorkoutLog.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// Logs (or re-logs) a set for today -- there's no DB-level uniqueness on
  /// (assignment_exercise_id, log_date), so "one row per exercise per day"
  /// is an app-level convention: update the existing row for today if one
  /// exists, otherwise insert. A client double-tapping quickly could race
  /// into two rows; acceptable for MVP single-user data, not worth a
  /// transactional RPC for.
  Future<void> logSet({
    String? existingLogId,
    required String clientId,
    required String assignmentExerciseId,
    required int actualSets,
    required String actualReps,
    num? actualWeightKg,
    int? perceivedEffort,
    String? notes,
  }) async {
    final payload = {
      'client_id': clientId,
      'assignment_exercise_id': assignmentExerciseId,
      'actual_sets': actualSets,
      'actual_reps': actualReps,
      'actual_weight_kg': actualWeightKg,
      'completed': true,
      'perceived_effort': perceivedEffort,
      'notes': notes,
    };

    if (existingLogId != null) {
      await _supabase.from('workout_logs').update(payload).eq('id', existingLogId);
    } else {
      await _supabase.from('workout_logs').insert(payload);
    }
  }
}

final workoutLogsRepositoryProvider = Provider<WorkoutLogsRepository>((ref) {
  return WorkoutLogsRepository(ref.watch(supabaseClientProvider));
});
