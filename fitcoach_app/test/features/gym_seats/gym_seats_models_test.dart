import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/gym_seats/data/gym_seats_models.dart';

void main() {
  group('Subscription.fromMap', () {
    test('reads an active trainer-owned subscription', () {
      final subscription = Subscription.fromMap({
        'id': 'sub-1',
        'owner_type': 'trainer',
        'owner_id': 'trainer-1',
        'plan_tier': 'starter_50',
        'seat_limit': 50,
        'seats_used': 12,
        'price_inr': 1000,
        'billing_period': 'monthly',
        'current_period_start': '2026-01-01T00:00:00Z',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(subscription.seatsRemaining, 38);
      expect(subscription.currentPeriodEnd, isNull);
    });

    test('clamps seatsRemaining at zero when oversold', () {
      final subscription = Subscription.fromMap({
        'id': 'sub-2',
        'owner_type': 'trainer',
        'owner_id': 'trainer-1',
        'plan_tier': 'starter_50',
        'seat_limit': 50,
        'seats_used': 50,
        'price_inr': 1000,
        'billing_period': 'monthly',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(subscription.seatsRemaining, 0);
    });
  });

  group('Invite.fromMap', () {
    test('reads a redeemable invite', () {
      final invite = Invite.fromMap({
        'id': 'inv-1',
        'subscription_id': 'sub-1',
        'created_by': 'trainer-1',
        'code': 'ABCD1234',
        'uses_count': 0,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(invite.isRedeemable, isTrue);
      expect(invite.isExpired, isFalse);
      expect(invite.isExhausted, isFalse);
    });

    test('treats a revoked invite as not redeemable', () {
      final invite = Invite.fromMap({
        'id': 'inv-2',
        'subscription_id': 'sub-1',
        'created_by': 'trainer-1',
        'code': 'EFGH5678',
        'uses_count': 1,
        'status': 'revoked',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(invite.isRedeemable, isFalse);
    });

    test('treats an exhausted invite (uses_count >= max_uses) as not redeemable', () {
      final invite = Invite.fromMap({
        'id': 'inv-3',
        'subscription_id': 'sub-1',
        'created_by': 'trainer-1',
        'code': 'IJKL9012',
        'max_uses': 3,
        'uses_count': 3,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(invite.isExhausted, isTrue);
      expect(invite.isRedeemable, isFalse);
    });

    test('treats a past expires_at as not redeemable', () {
      final invite = Invite.fromMap({
        'id': 'inv-4',
        'subscription_id': 'sub-1',
        'created_by': 'trainer-1',
        'code': 'MNOP3456',
        'uses_count': 0,
        'expires_at': '2020-01-01T00:00:00Z',
        'status': 'active',
        'created_at': '2020-01-01T00:00:00Z',
      });
      expect(invite.isExpired, isTrue);
      expect(invite.isRedeemable, isFalse);
    });
  });
}
