import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import 'programs_providers.dart';

const _statusLabels = {'active': 'Active', 'canceled': 'Canceled', 'past_due': 'Past due'};

/// Client side "My Programs" -- the subscribed-programs list, per this
/// milestone's own scope. Reached from Client Profile only, same "pushed
/// route off Profile" precedent as gym_seats' redeem-invite screen
/// (Milestone 7). No cancel-subscription action here -- not built this
/// milestone, see Milestone 8.md's known gaps.
class MyProgramsScreen extends ConsumerWidget {
  const MyProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(myProgramSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Programs')),
      body: subscriptionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your programs: $error')),
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No programs yet. Subscribe to one from Discover.', textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myProgramSubscriptionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subscriptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final subscription = subscriptions[index];
                final program = subscription.program;
                return Card(
                  child: ListTile(
                    title: Text(program?.title ?? 'Program'),
                    subtitle: Text(
                      '${_statusLabels[subscription.status] ?? subscription.status} · '
                      '₹${subscription.pricePaidInr.toStringAsFixed(0)} paid · '
                      'started ${DateFormat.yMMMd().format(subscription.startedAt)}',
                    ),
                    trailing: subscription.status == 'active'
                        ? null
                        : const Icon(Icons.info_outline, color: AppColors.inkSoftLight),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
