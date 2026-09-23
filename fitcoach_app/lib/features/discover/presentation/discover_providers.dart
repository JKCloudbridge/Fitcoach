import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/discover_models.dart';
import '../data/discover_repository.dart';

final discoverCardsProvider = FutureProvider.autoDispose<List<DiscoverCard>>((ref) {
  return ref.watch(discoverRepositoryProvider).fetchPublicCards();
});

final savedCardIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final clientId = ref.watch(authProvider.select((s) => s.userId));
  if (clientId == null) return const {};
  return ref.watch(discoverRepositoryProvider).fetchSavedCardIds(clientId);
});
