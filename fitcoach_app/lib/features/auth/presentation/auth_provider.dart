import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateNotifier/StateNotifierProvider moved to this explicit import in
// Riverpod 3.x -- the plain Notifier/NotifierProvider in the main package
// are for riverpod_generator's @riverpod codegen, not hand-writing, and
// FitCoach dropped codegen at Milestone 0 (see pubspec.yaml comment) same as
// Proximity.
import 'package:flutter_riverpod/legacy.dart';

import '../data/auth_repository.dart';

/// `role` is null both while it's still resolving (`isLoading == true`) and
/// once resolved for a signed-in user with no profile row yet -- callers
/// that need to tell those apart check `isLoading` first, same as the
/// redirect guard in app_router.dart does.
class AuthSessionState {
  const AuthSessionState({this.isLoggedIn = false, this.userId, this.role, this.isLoading = true});

  final bool isLoggedIn;
  final String? userId;
  final String? role; // 'trainer' | 'client' | null
  final bool isLoading;

  AuthSessionState copyWith({bool? isLoggedIn, String? userId, String? role, bool? isLoading, bool clearUserId = false, bool clearRole = false}) {
    return AuthSessionState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: clearUserId ? null : (userId ?? this.userId),
      role: clearRole ? null : (role ?? this.role),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthSessionState> {
  AuthNotifier(this._repository) : super(const AuthSessionState()) {
    _subscription = _repository.onAuthStateChange.listen((_) => _sync());
    _sync();
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _subscription;

  Future<void> _sync() async {
    // Wrapped defensively -- a Keystore/Keychain write failure must never
    // leave isLoading stuck true, since the router's redirect refuses to act
    // while isLoading (same lesson Proximity's own comment calls out).
    try {
      await _repository.syncSessionToStorage();
    } catch (_) {
      // ignore -- Dio's interceptor just won't find a cached JWT
    }

    final session = _repository.currentSession;
    if (session == null) {
      state = const AuthSessionState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoggedIn: true, userId: session.user.id, isLoading: true);

    final role = await _resolveRoleSafely(session.user.id);
    state = state.copyWith(role: role, clearRole: role == null, isLoading: false);
  }

  /// Called by the role-select screen right after it inserts a
  /// trainer_profiles/client_profiles row, so the app doesn't need to wait
  /// on a full session/token refresh to notice the new role.
  Future<void> refreshRole() async {
    final userId = state.userId;
    if (userId == null) return;
    final role = await _resolveRoleSafely(userId);
    state = state.copyWith(role: role, clearRole: role == null);
  }

  Future<String?> _resolveRoleSafely(String userId) async {
    try {
      return await _repository.resolveRole(userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> sendEmailOtp(String email) => _repository.sendEmailOtp(email);

  Future<void> verifyEmailOtp({required String email, required String token}) {
    return _repository.verifyEmailOtp(email: email, token: token);
  }

  Future<void> signInWithGoogle() => _repository.signInWithGoogle();

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthSessionState(isLoading: false);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthSessionState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Bounded busy-poll (not an unbounded `firstWhere`) closing a real race:
/// a sign-in call resolving does not mean `authProvider`'s state has caught
/// up yet, since that update happens on the separate `onAuthStateChange`
/// listener -- same pattern and same reasoning as Proximity's
/// `waitUntilLoggedIn`, extended here to also wait for role resolution so
/// the router's redirect has enough information to pick a destination.
Future<void> waitUntilLoggedIn(WidgetRef ref, {Duration timeout = const Duration(seconds: 3)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final state = ref.read(authProvider);
    if (state.isLoggedIn && !state.isLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}
