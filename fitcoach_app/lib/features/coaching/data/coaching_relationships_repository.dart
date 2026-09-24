import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';

/// A trainer's active client, joined from coaching_relationships +
/// client_profiles -- just enough to populate the "Assign to" picker in
/// workout_cards' build_session_screen.dart. A full roster/"Clients" tab
/// screen is explicitly out of scope this milestone (still a ComingSoonScreen
/// in app_router.dart) -- this is the minimal read that flow needs, not a
/// roster feature.
class CoachingClient {
  const CoachingClient({required this.relationshipId, required this.clientId, this.displayName});

  final String relationshipId;
  final String clientId;
  final String? displayName;
}

/// The client-side mirror of [CoachingClient] -- Milestone 6's messaging
/// "start a new conversation" picker needs a client to pick from among their
/// own active trainer(s) (private coach and/or gym trainer, per Plan.md's
/// "three coaching relationships in one app"), symmetric to how the
/// trainer-side picker already uses [CoachingClient].
class CoachingTrainer {
  const CoachingTrainer({required this.relationshipId, required this.trainerId, this.displayName});

  final String relationshipId;
  final String trainerId;
  final String? displayName;
}

/// Direct RLS-gated read on coaching_relationships (migration 005:
/// `trainer_id = auth.uid()` select policy) -- no Edge Function needed for a
/// trainer reading their own relationships.
class CoachingRelationshipsRepository {
  CoachingRelationshipsRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<CoachingClient>> fetchActiveClients(String trainerId) async {
    final rows = await _supabase
        .from('coaching_relationships')
        .select('id, client_id, client_profiles(display_name)')
        .eq('trainer_id', trainerId)
        .eq('status', 'active');
    return (rows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final client = map['client_profiles'] as Map<String, dynamic>?;
      return CoachingClient(
        relationshipId: map['id'] as String,
        clientId: map['client_id'] as String,
        displayName: client?['display_name'] as String?,
      );
    }).toList();
  }

  /// Reverse direction of [fetchActiveClients] -- a client's own active
  /// trainer(s). `trainer_profiles` is public-select (migration 003), so no
  /// RLS gap here the way there was on the client_profiles side (see
  /// migration 020).
  Future<List<CoachingTrainer>> fetchActiveTrainers(String clientId) async {
    final rows = await _supabase
        .from('coaching_relationships')
        .select('id, trainer_id, trainer_profiles(display_name)')
        .eq('client_id', clientId)
        .eq('status', 'active');
    return (rows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final trainer = map['trainer_profiles'] as Map<String, dynamic>?;
      return CoachingTrainer(
        relationshipId: map['id'] as String,
        trainerId: map['trainer_id'] as String,
        displayName: trainer?['display_name'] as String?,
      );
    }).toList();
  }
}

final coachingRelationshipsRepositoryProvider = Provider<CoachingRelationshipsRepository>((ref) {
  return CoachingRelationshipsRepository(ref.watch(supabaseClientProvider));
});
