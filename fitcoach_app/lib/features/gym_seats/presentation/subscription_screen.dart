import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/gym_seats_models.dart';
import '../data/invites_repository.dart';
import '../data/subscriptions_repository.dart';
import 'create_invite_sheet.dart';
import 'gym_seats_providers.dart';

/// Trainer/org-owner side of gym seat licensing (Requirement 1 §10):
/// subscribe to a seat tier, then create/manage invite codes clients redeem
/// to connect. No mockup precedent for this screen -- same "design it
/// yourself, consistent with the app's existing visual language" situation
/// Milestone 6 was in for messaging -- laid out following this app's
/// existing list-screen convention (AppBar + ListView, card sections) rather
/// than the concept HTML, since it has no gym/seat/invite screens to match.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Seats & invites')),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your subscription: $error')),
        data: (subscription) {
          if (subscription == null) {
            return const _PlanPicker();
          }
          return _SubscriptionDetail(subscription: subscription);
        },
      ),
    );
  }
}

class _PlanPicker extends ConsumerStatefulWidget {
  const _PlanPicker();

  @override
  ConsumerState<_PlanPicker> createState() => _PlanPickerState();
}

class _PlanPickerState extends ConsumerState<_PlanPicker> {
  bool _creating = false;
  String? _error;

  Future<void> _choose(PlanTierOption plan) async {
    final trainerId = ref.read(authProvider).userId;
    if (trainerId == null) return;

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionsRepositoryProvider).createSubscription(trainerId: trainerId, plan: plan);
      ref.invalidate(mySubscriptionProvider);
    } catch (e) {
      setState(() => _error = 'Could not start this plan: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Choose a seat plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'A seat plan lets you invite your real clients to connect directly, instead of them finding you '
          'through Discover. Each redeemed invite uses one seat.',
          style: TextStyle(color: AppColors.inkSoftLight),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.stoneLight, borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'No payment gateway is wired up yet -- choosing a plan activates it immediately for testing. '
            'Real billing is a pending follow-up (see Milestone 7 manual steps).',
            style: TextStyle(fontSize: 12.5, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 20),
        for (final plan in kPlanTierOptions) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(plan.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${plan.seatLimit} seats · ₹${plan.priceInr.toStringAsFixed(0)}/mo'),
              trailing: _creating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _creating ? null : () => _choose(plan),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _SubscriptionDetail extends ConsumerWidget {
  const _SubscriptionDetail({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(subscriptionInvitesProvider(subscription.id));
    final plan = kPlanTierOptions.firstWhere((p) => p.tier == subscription.planTier, orElse: () => kPlanTierOptions.first);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mySubscriptionProvider);
        ref.invalidate(subscriptionInvitesProvider(subscription.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(plan.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(subscription.status, style: TextStyle(color: subscription.status == 'active' ? AppColors.ink : AppColors.coral)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: subscription.seatLimit == 0 ? 0 : subscription.seatsUsed / subscription.seatLimit,
                    backgroundColor: AppColors.stoneLight,
                  ),
                  const SizedBox(height: 8),
                  Text('${subscription.seatsUsed} of ${subscription.seatLimit} seats used'),
                  Text('₹${subscription.priceInr.toStringAsFixed(0)}/mo', style: const TextStyle(color: AppColors.inkSoftLight)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Invites', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                onPressed: subscription.seatsRemaining <= 0
                    ? null
                    : () async {
                        final created = await showCreateInviteSheet(context, subscriptionId: subscription.id);
                        if (created != null) ref.invalidate(subscriptionInvitesProvider(subscription.id));
                      },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New invite'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          invitesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load invites: $error'),
            data: (invites) {
              if (invites.isEmpty) {
                return const Text(
                  'No invites yet. Create one and share the code with a client -- they redeem it from their Profile screen.',
                  style: TextStyle(color: AppColors.inkSoftLight),
                );
              }
              return Column(
                children: [for (final invite in invites) _InviteTile(invite: invite, subscriptionId: subscription.id)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite, required this.subscriptionId});

  final Invite invite;
  final String subscriptionId;

  String get _statusLabel {
    if (invite.status == 'revoked') return 'Revoked';
    if (invite.isExpired) return 'Expired';
    if (invite.isExhausted) return 'Fully used';
    return 'Active';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Text(invite.code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        subtitle: Text(
          '$_statusLabel · used ${invite.usesCount}${invite.maxUses != null ? '/${invite.maxUses}' : ''}'
          '${invite.expiresAt != null ? ' · expires ${DateFormat.yMMMd().format(invite.expiresAt!)}' : ''}',
        ),
        trailing: invite.isRedeemable
            ? TextButton(
                onPressed: () async {
                  await ref.read(invitesRepositoryProvider).revokeInvite(invite.id);
                  ref.invalidate(subscriptionInvitesProvider(subscriptionId));
                },
                child: const Text('Revoke'),
              )
            : null,
      ),
    );
  }
}
