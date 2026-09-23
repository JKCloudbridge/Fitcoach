import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/core/router/redirect_logic.dart';

void main() {
  group('resolveRedirect', () {
    test('does nothing while auth is still resolving', () {
      expect(resolveRedirect(isLoading: true, isLoggedIn: false, role: null, path: '/client'), isNull);
    });

    test('sends a signed-out user to /login', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: false, role: null, path: '/client'), '/login');
    });

    test('leaves a signed-out user on /login alone', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: false, role: null, path: '/login'), isNull);
      expect(resolveRedirect(isLoading: false, isLoggedIn: false, role: null, path: '/login/verify-otp'), isNull);
    });

    test('sends a signed-in user with no profile row to role-select', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: null, path: '/client'), '/onboarding/role-select');
    });

    test('leaves a signed-in, roleless user on role-select alone', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: null, path: '/onboarding/role-select'), isNull);
    });

    test('bounces a signed-in, roled user off /login to their shell', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'trainer', path: '/login'), '/trainer');
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'client', path: '/login'), '/client');
    });

    test('bounces a signed-in, roled user off role-select to their shell', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'trainer', path: '/onboarding/role-select'), '/trainer');
    });

    test('leaves a signed-in, roled user on their own shell routes alone', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'client', path: '/client/profile'), isNull);
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'trainer', path: '/trainer/cards'), isNull);
    });

    test('bounces a client out of the trainer shell and vice versa', () {
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'client', path: '/trainer/cards'), '/client');
      expect(resolveRedirect(isLoading: false, isLoggedIn: true, role: 'trainer', path: '/client/progress'), '/trainer');
    });
  });
}
