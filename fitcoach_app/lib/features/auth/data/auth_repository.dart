import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/storage/secure_storage.dart';

/// The only place in the app allowed to touch `supabase_flutter` directly for
/// auth, same "single seam" convention as both sibling apps' AuthRepository --
/// everything else in FitCoach's hybrid backend pattern reads tables straight
/// through `supabaseClientProvider` per feature (per CLAUDE.md), but auth
/// state and role resolution funnel through here so there's one place that
/// knows about `Session`/`AuthException`/etc.
class AuthRepository {
  AuthRepository(this._supabase, this._secureStorage, this._googleSignIn);

  final SupabaseClient _supabase;
  final SecureStorage _secureStorage;
  final GoogleSignIn _googleSignIn;

  /// Erased to `Stream<void>` deliberately -- consumers re-read
  /// `currentSession` fresh rather than trusting the event payload, keeping
  /// this the single seam that knows about supabase_flutter's own types
  /// (same reasoning as both sibling apps).
  Stream<void> get onAuthStateChange => _supabase.auth.onAuthStateChange.map((_) {});

  Session? get currentSession => _supabase.auth.currentSession;

  /// Sends a 6-digit email OTP. `shouldCreateUser: true` (the default) means
  /// this doubles as sign-up for a brand-new email -- FitCoach has no
  /// separate signup screen, matching the "Google Sign-In + Email OTP" scope
  /// (no password, unlike Proximity's current password+OTP-confirmation
  /// flow -- this is the true passwordless flow baker_ally used before it
  /// moved to passwords).
  Future<void> sendEmailOtp(String email) {
    return _supabase.auth.signInWithOtp(email: email);
  }

  Future<void> verifyEmailOtp({required String email, required String token}) {
    return _supabase.auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  /// google_sign_in v7's native ID-token exchange, not the browser-tab
  /// `signInWithOAuth` handoff -- requires `GoogleSignIn.instance.initialize`
  /// to have already completed in main.dart.
  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token');
    }
    await _supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _secureStorage.clearJwt();
  }

  Future<void> syncSessionToStorage() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      await _secureStorage.writeJwt(session.accessToken);
    } else {
      await _secureStorage.clearJwt();
    }
  }

  /// Role is presence-of-profile-row, not a trusted JWT claim read
  /// client-side -- the `custom_access_token_hook` claim (migration 004) is
  /// only "a convenience for RLS/Edge Function checks that need a single
  /// value" per its own comment, not meant as the app's source of truth.
  /// Querying directly also avoids needing a session refresh immediately
  /// after role-select inserts a profile row.
  Future<String?> resolveRole(String userId) async {
    final trainerRow = await _supabase.from('trainer_profiles').select('id').eq('id', userId).maybeSingle();
    if (trainerRow != null) return 'trainer';

    final clientRow = await _supabase.from('client_profiles').select('id').eq('id', userId).maybeSingle();
    if (clientRow != null) return 'client';

    return null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(secureStorageProvider),
    ref.watch(googleSignInProvider),
  );
});
