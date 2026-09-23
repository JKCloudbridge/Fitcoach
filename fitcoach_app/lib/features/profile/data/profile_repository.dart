import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'profile_models.dart';

/// Direct RLS-gated reads/writes on trainer_profiles/client_profiles, per
/// CLAUDE.md's hybrid backend pattern -- these are simple single-row
/// operations RLS already gates (migrations/003_rls_foundation.sql:
/// `id = auth.uid()` for writes), so no Edge Function is needed.
class ProfileRepository {
  ProfileRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Role-select screen's write -- the row's existence is itself what
  /// custom_access_token_hook (migration 004) and AuthRepository.resolveRole
  /// treat as "this user is a trainer/client".
  Future<void> createTrainerProfile({required String userId, required String displayName}) {
    return _supabase.from('trainer_profiles').insert({'id': userId, 'display_name': displayName});
  }

  Future<void> createClientProfile({required String userId, required String displayName}) {
    return _supabase.from('client_profiles').insert({'id': userId, 'display_name': displayName});
  }

  Future<TrainerProfile?> fetchTrainerProfile(String userId) async {
    final row = await _supabase.from('trainer_profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : TrainerProfile.fromMap(row);
  }

  Future<ClientProfile?> fetchClientProfile(String userId) async {
    final row = await _supabase.from('client_profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : ClientProfile.fromMap(row);
  }

  Future<void> updateTrainerProfile({
    required String userId,
    required String? displayName,
    required String? bio,
    required List<String> certifications,
  }) {
    return _supabase.from('trainer_profiles').update({
      'display_name': displayName,
      'bio': bio,
      'certifications': certifications,
    }).eq('id', userId);
  }

  Future<void> updateClientProfile({
    required String userId,
    required String? displayName,
    required DateTime? dateOfBirth,
    required num? heightCm,
    required num? weightKg,
    required List<String> goals,
  }) {
    return _supabase.from('client_profiles').update({
      'display_name': displayName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goals': goals,
    }).eq('id', userId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
