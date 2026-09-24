import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'program_models.dart';

/// Direct-RLS read on program_subscriptions (migration 024) -- per §13, only
/// GET is listed for this table; creation/status changes are RPC-only (see
/// subscribe_program_repository.dart and migration 029), read is plain
/// supabase_flutter + RLS.
class ProgramSubscriptionsRepository {
  ProgramSubscriptionsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// The signed-in client's own subscriptions ("My Programs"), newest first,
  /// with the parent program embedded so the list screen doesn't need a
  /// second round trip.
  Future<List<ProgramSubscription>> fetchMySubscriptions(String clientId) async {
    final rows = await _supabase
        .from('program_subscriptions')
        .select('*, programs(*, trainer_profiles(display_name), workout_cards(id,title))')
        .eq('client_id', clientId)
        .order('started_at', ascending: false);
    return (rows as List<dynamic>).map((row) => ProgramSubscription.fromMap(row as Map<String, dynamic>)).toList();
  }
}

final programSubscriptionsRepositoryProvider = Provider<ProgramSubscriptionsRepository>((ref) {
  return ProgramSubscriptionsRepository(ref.watch(supabaseClientProvider));
});
