/// Pure, unit-testable core of the router's redirect guard -- kept separate
/// from GoRouterState/BuildContext/WidgetRef so it can be exercised in
/// `flutter test` without mocking GoRouter or Supabase (Milestone 0's own
/// placeholder test flagged that gap; this is the dedicated testing pass for
/// the auth-aware part of it).
///
/// `role` is only meaningful when `isLoading` is false -- the caller (the
/// GoRouter `redirect` callback) reads it off `AuthSessionState`, which
/// keeps `role: null` both while resolving and once resolved-but-absent;
/// this function only runs the role-based decisions once `isLoading` is
/// false, so it never confuses the two.
String? resolveRedirect({required bool isLoading, required bool isLoggedIn, required String? role, required String path}) {
  if (isLoading) return null;

  final atAuthRoute = path == '/login' || path.startsWith('/login/');
  final atRoleSelect = path == '/onboarding/role-select';

  if (!isLoggedIn) {
    return atAuthRoute ? null : '/login';
  }

  if (atAuthRoute) {
    return role == null ? '/onboarding/role-select' : _homeFor(role);
  }

  if (role == null) {
    return atRoleSelect ? null : '/onboarding/role-select';
  }

  if (atRoleSelect) {
    return _homeFor(role);
  }

  // Defensive cross-shell guard -- not reachable via the app's own UI (each
  // shell only links to its own routes), but a deep link/restored route
  // could still hit the wrong shell for the signed-in user's role.
  if (role == 'client' && path.startsWith('/trainer')) {
    return _homeFor(role);
  }
  if (role == 'trainer' && path.startsWith('/client')) {
    return _homeFor(role);
  }

  return null;
}

String _homeFor(String role) => role == 'trainer' ? '/trainer' : '/client';
