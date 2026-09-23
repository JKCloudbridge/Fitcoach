import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'discover_models.dart';

/// Direct RLS-gated reads/writes on workout_cards, saved_cards, and
/// card_reports, per CLAUDE.md's hybrid backend pattern -- per Requirement 1
/// §6.5, Discover's own API section lists all of these as plain REST calls,
/// not Edge Function routes: browsing public cards is a simple visibility-
/// gated read (migration 006's RLS), bookmarking is single-owner data
/// (migration 011), and filing a report is insert-only, unreadable back (migration
/// 012). Only *starting* a card (workout_cards -> workout_assignments, across
/// the client/no-trainer boundary, plus the card_stats.follow_count bump) is
/// cross-cutting enough to need an Edge Function -- see
/// follow_public_card_repository.dart.
class DiscoverRepository {
  DiscoverRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<DiscoverCard>> fetchPublicCards() async {
    final rows = await _supabase
        .from('workout_cards')
        .select('*, trainer_profiles(display_name)')
        .eq('visibility', 'public')
        .eq('is_published', true)
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((row) => DiscoverCard.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<Set<String>> fetchSavedCardIds(String clientId) async {
    final rows = await _supabase.from('saved_cards').select('card_id').eq('client_id', clientId);
    return (rows as List<dynamic>).map((row) => (row as Map<String, dynamic>)['card_id'] as String).toSet();
  }

  Future<void> saveCard({required String clientId, required String cardId}) {
    return _supabase.from('saved_cards').insert({'client_id': clientId, 'card_id': cardId});
  }

  Future<void> unsaveCard({required String clientId, required String cardId}) {
    return _supabase.from('saved_cards').delete().eq('client_id', clientId).eq('card_id', cardId);
  }

  Future<void> reportCard({required String cardId, required String reportedBy, required String reason}) {
    return _supabase.from('card_reports').insert({'card_id': cardId, 'reported_by': reportedBy, 'reason': reason});
  }
}

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository(ref.watch(supabaseClientProvider));
});
