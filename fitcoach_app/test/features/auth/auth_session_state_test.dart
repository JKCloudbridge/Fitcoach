import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/auth/presentation/auth_provider.dart';

void main() {
  group('AuthSessionState.copyWith', () {
    test('defaults to a loading, signed-out state', () {
      const state = AuthSessionState();
      expect(state.isLoggedIn, isFalse);
      expect(state.userId, isNull);
      expect(state.role, isNull);
      expect(state.isLoading, isTrue);
    });

    test('carries fields forward when not overridden', () {
      const state = AuthSessionState(isLoggedIn: true, userId: 'user-1', role: 'trainer', isLoading: false);
      final copy = state.copyWith(isLoading: true);
      expect(copy.isLoggedIn, isTrue);
      expect(copy.userId, 'user-1');
      expect(copy.role, 'trainer');
      expect(copy.isLoading, isTrue);
    });

    test('clearUserId/clearRole null out those fields even though they are truthy-checked elsewhere', () {
      const state = AuthSessionState(isLoggedIn: true, userId: 'user-1', role: 'trainer', isLoading: false);
      final copy = state.copyWith(clearUserId: true, clearRole: true);
      expect(copy.userId, isNull);
      expect(copy.role, isNull);
    });
  });
}
