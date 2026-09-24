import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'gym_seats_models.dart';

/// Direct-RLS reads/writes on `invites` (migration 021) -- same
/// permissive-direct-insert pattern as subscriptions_repository.dart. `code`
/// is DB-generated (column default, migration 021), not sent by the client.
/// Redeeming an invite is the one write that isn't here -- see
/// redeem_invite_repository.dart, the Edge Function call.
class InvitesRepository {
  InvitesRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Invite>> fetchInvites(String subscriptionId) async {
    final rows = await _supabase.from('invites').select().eq('subscription_id', subscriptionId).order('created_at', ascending: false);
    return (rows as List).map((row) => Invite.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<Invite> createInvite({required String subscriptionId, required String createdBy, int? maxUses, DateTime? expiresAt}) async {
    final row = await _supabase
        .from('invites')
        .insert({
          'subscription_id': subscriptionId,
          'created_by': createdBy,
          'max_uses': ?maxUses,
          'expires_at': ?expiresAt?.toUtc().toIso8601String(),
        })
        .select()
        .single();
    return Invite.fromMap(row);
  }

  /// Narrowed to the `status` column by migration 021's grant -- can never
  /// touch uses_count/code/etc. through this path even if the payload did.
  Future<void> revokeInvite(String inviteId) {
    return _supabase.from('invites').update({'status': 'revoked'}).eq('id', inviteId);
  }
}

final invitesRepositoryProvider = Provider<InvitesRepository>((ref) {
  return InvitesRepository(ref.watch(supabaseClientProvider));
});
