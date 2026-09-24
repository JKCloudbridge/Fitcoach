import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'gym_seats_models.dart';

/// Direct-RLS reads/writes on `subscriptions` (migration 021) -- per §13,
/// creating a subscription is a direct insert by the owning trainer/org, no
/// Edge Function needed (see migration 021's header note). Only the
/// owner_type = 'trainer' case is used by this app's UI so far -- see
/// [SubscriptionsRepository.fetchMySubscription].
class SubscriptionsRepository {
  SubscriptionsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// The signed-in trainer's own subscription, if any. Gym
  /// (owner_type = 'organization') subscriptions aren't surfaced here --
  /// there's no gym-admin/roster UI anywhere else in this app yet to manage
  /// one, so this milestone's UI only covers an independent trainer buying
  /// their own seats (schema/RLS support organization-owned rows from day
  /// one, ready for whenever that admin UI gets built).
  Future<Subscription?> fetchMySubscription(String trainerId) async {
    final rows = await _supabase
        .from('subscriptions')
        .select()
        .eq('owner_type', 'trainer')
        .eq('owner_id', trainerId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Subscription.fromMap(list.first as Map<String, dynamic>);
  }

  /// Self-serve: no payment gateway wired up yet (see Milestone 7.md's
  /// decision log), so this activates the seat license immediately on
  /// insert -- same "permissive by design for MVP" treatment
  /// coaching_relationships got in Milestone 2.
  Future<Subscription> createSubscription({required String trainerId, required PlanTierOption plan}) async {
    final now = DateTime.now().toUtc();
    final row = await _supabase
        .from('subscriptions')
        .insert({
          'owner_type': 'trainer',
          'owner_id': trainerId,
          'plan_tier': plan.tier,
          'seat_limit': plan.seatLimit,
          'price_inr': plan.priceInr,
          'billing_period': 'monthly',
          'current_period_start': now.toIso8601String(),
        })
        .select()
        .single();
    return Subscription.fromMap(row);
  }
}

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return SubscriptionsRepository(ref.watch(supabaseClientProvider));
});
