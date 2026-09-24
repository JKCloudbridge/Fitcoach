import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/gym_seats_models.dart';
import '../data/invites_repository.dart';
import '../data/subscriptions_repository.dart';

final mySubscriptionProvider = FutureProvider.autoDispose<Subscription?>((ref) async {
  final auth = ref.watch(authProvider);
  final userId = auth.userId;
  if (userId == null || auth.role != 'trainer') return null;
  return ref.watch(subscriptionsRepositoryProvider).fetchMySubscription(userId);
});

final subscriptionInvitesProvider = FutureProvider.autoDispose.family<List<Invite>, String>((ref, subscriptionId) {
  return ref.watch(invitesRepositoryProvider).fetchInvites(subscriptionId);
});
