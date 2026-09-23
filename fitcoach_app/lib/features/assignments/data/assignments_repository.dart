import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'assignment_models.dart';

/// Direct RLS-gated read on workout_assignments/assignment_exercises
/// (migration 007: `client_id = auth.uid()` select policy) -- reading your
/// own active plan is a simple RLS-gated read, per CLAUDE.md's hybrid
/// pattern. *Creating* an assignment is Edge-Function-only -- see
/// workout_cards/data/assign_workout_card_repository.dart.
class AssignmentsRepository {
  AssignmentsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// The client's single most-recently-assigned active plan. Doesn't yet
  /// disambiguate multiple concurrent active assignments (e.g. a
  /// trainer-assigned plan alongside a self-saved one from Discover) --
  /// Discover/self_saved isn't built this milestone, so there's at most one
  /// in practice today; flagged as a known simplification for when that
  /// changes.
  Future<(WorkoutAssignment, List<AssignmentExercise>)?> fetchActiveAssignment(String clientId) async {
    final rows = await _supabase
        .from('workout_assignments')
        .select('*, workout_cards(title), trainer_profiles(display_name), assignment_exercises(*)')
        .eq('client_id', clientId)
        .eq('status', 'active')
        .order('assigned_at', ascending: false)
        .order('order_index', referencedTable: 'assignment_exercises')
        .limit(1);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;

    final row = list.first as Map<String, dynamic>;
    final exerciseRows = (row['assignment_exercises'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final exercises = exerciseRows.map(AssignmentExercise.fromMap).toList();
    return (WorkoutAssignment.fromMap(row), exercises);
  }
}

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  return AssignmentsRepository(ref.watch(supabaseClientProvider));
});
