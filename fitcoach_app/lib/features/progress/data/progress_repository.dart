import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../workout_logs/data/workout_log_models.dart';
import 'progress_models.dart';

/// Direct RLS-gated reads on workout_logs, joined with assignment_exercises
/// for exercise names -- both existing Milestone 2 tables, no new schema.
/// Progress deliberately doesn't touch wearable_metrics (Milestone 5) or
/// build its own aggregate table -- the doc's own scope for this milestone
/// is "what's actually derivable from data that exists now".
class ProgressRepository {
  ProgressRepository(this._supabase);

  final SupabaseClient _supabase;

  /// All logs from [weekStart] onward, for the weekly adherence bars.
  /// `weekStart` is expected to be that week's Monday (see
  /// progress_providers.dart's `_mondayOf`).
  Future<List<WorkoutLog>> fetchLogsSince(String clientId, DateTime weekStart) async {
    final rows = await _supabase.from('workout_logs').select().eq('client_id', clientId).gte('log_date', _dateOnly(weekStart));
    return (rows as List<dynamic>).map((row) => WorkoutLog.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// Every weighted set the client has ever logged, most recent first, for
  /// the personal-record card.
  Future<List<WeightLogEntry>> fetchWeightLogs(String clientId) async {
    final rows = await _supabase
        .from('workout_logs')
        .select('actual_weight_kg, log_date, assignment_exercises(name)')
        .eq('client_id', clientId)
        .not('actual_weight_kg', 'is', null)
        .order('log_date', ascending: false);
    return (rows as List<dynamic>).map((row) => WeightLogEntry.fromMap(row as Map<String, dynamic>)).toList();
  }

  String _dateOnly(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(supabaseClientProvider));
});
