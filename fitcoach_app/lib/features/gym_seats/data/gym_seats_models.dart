/// One row from `subscriptions` (migration 021), per Requirement 1 §10.1.
/// This app only ever creates/reads owner_type = 'trainer' rows so far --
/// owner_type = 'organization' is schema/RLS-ready but has no gym-admin UI
/// anywhere in this app yet to manage one (see gym_seats' presentation
/// layer note).
class Subscription {
  const Subscription({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.planTier,
    required this.seatLimit,
    required this.seatsUsed,
    required this.priceInr,
    required this.billingPeriod,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String ownerType;
  final String ownerId;
  final String planTier;
  final int seatLimit;
  final int seatsUsed;
  final num priceInr;
  final String billingPeriod;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final String status;
  final DateTime createdAt;

  int get seatsRemaining => (seatLimit - seatsUsed).clamp(0, seatLimit);

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: map['id'] as String,
    ownerType: map['owner_type'] as String,
    ownerId: map['owner_id'] as String,
    planTier: map['plan_tier'] as String,
    seatLimit: map['seat_limit'] as int,
    seatsUsed: map['seats_used'] as int,
    priceInr: map['price_inr'] as num,
    billingPeriod: map['billing_period'] as String,
    currentPeriodStart: map['current_period_start'] != null ? DateTime.parse(map['current_period_start'] as String) : null,
    currentPeriodEnd: map['current_period_end'] != null ? DateTime.parse(map['current_period_end'] as String) : null,
    status: map['status'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// One row from `invites` (migration 021), per Requirement 1 §10.2.
class Invite {
  const Invite({
    required this.id,
    required this.subscriptionId,
    required this.createdBy,
    required this.code,
    this.maxUses,
    required this.usesCount,
    this.expiresAt,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String createdBy;
  final String code;
  final int? maxUses;
  final int usesCount;
  final DateTime? expiresAt;
  final String status;
  final DateTime createdAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isExhausted => maxUses != null && usesCount >= maxUses!;
  bool get isRedeemable => status == 'active' && !isExpired && !isExhausted;

  factory Invite.fromMap(Map<String, dynamic> map) => Invite(
    id: map['id'] as String,
    subscriptionId: map['subscription_id'] as String,
    createdBy: map['created_by'] as String,
    code: map['code'] as String,
    maxUses: map['max_uses'] as int?,
    usesCount: map['uses_count'] as int,
    expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at'] as String) : null,
    status: map['status'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// A seat-license tier a trainer can self-serve into, per Requirement 1
/// §10.4. Pricing ladder is an explicitly open decision there (linear vs.
/// degressive) -- these three use the doc's own linear example (₹20/seat
/// flat) since that's the only concrete numbers it gives, not a resolution
/// of that open decision. Plain data, not schema -- trivial to swap for a
/// degressive ladder later without a migration.
class PlanTierOption {
  const PlanTierOption({required this.tier, required this.label, required this.seatLimit, required this.priceInr});

  final String tier;
  final String label;
  final int seatLimit;
  final num priceInr;
}

const kPlanTierOptions = [
  PlanTierOption(tier: 'starter_50', label: 'Starter', seatLimit: 50, priceInr: 1000),
  PlanTierOption(tier: 'growth_100', label: 'Growth', seatLimit: 100, priceInr: 2000),
  PlanTierOption(tier: 'pro_250', label: 'Pro', seatLimit: 250, priceInr: 5000),
];
