import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/discover_models.dart';
import '../data/discover_repository.dart';
import '../utils/filter_discover_cards.dart';
import 'card_detail_sheet.dart';
import 'discover_providers.dart';

const _filters = [
  ('all', 'All'),
  ('strength', 'Strength'),
  ('mobility', 'Mobility'),
  ('conditioning', 'Conditioning'),
];

/// Client "Discover" -- public workout_cards, per the UI concept's
/// screenDiscover() (filter chips + disc-card rows with a bookmark toggle).
/// No separate "Saved" screen -- filtering to just-saved cards is the same
/// chip row's job (see the trailing chip below), matching the concept's own
/// single-screen shape rather than adding a screen it doesn't show.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _filter = 'all';
  bool _savedOnly = false;

  Future<void> _toggleSave(DiscoverCard card, bool currentlySaved) async {
    final clientId = ref.read(authProvider).userId;
    if (clientId == null) return;

    final repository = ref.read(discoverRepositoryProvider);
    try {
      if (currentlySaved) {
        await repository.unsaveCard(clientId: clientId, cardId: card.id);
      } else {
        await repository.saveCard(clientId: clientId, cardId: card.id);
      }
      ref.invalidate(savedCardIdsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update saved cards: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(discoverCardsProvider);
    final savedIds = ref.watch(savedCardIdsProvider).maybeWhen(data: (ids) => ids, orElse: () => const <String>{});

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load Discover: $error')),
        data: (cards) {
          final byFilter = filterDiscoverCards(cards, _filter);
          final shown = _savedOnly ? byFilter.where((card) => savedIds.contains(card.id)).toList() : byFilter;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(discoverCardsProvider);
              ref.invalidate(savedCardIdsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Public library', style: TextStyle(fontSize: 12)),
                const Text('Discover', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Programs published by coaches on FitCoach'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final (key, label) in _filters)
                      ChoiceChip(label: Text(label), selected: _filter == key, onSelected: (_) => setState(() => _filter = key)),
                    ChoiceChip(
                      label: const Text('Saved'),
                      avatar: const Icon(Icons.bookmark, size: 14),
                      selected: _savedOnly,
                      onSelected: (value) => setState(() => _savedOnly = value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (cards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No public cards yet — check back soon.', textAlign: TextAlign.center),
                  )
                else if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('Nothing matches this filter yet.', textAlign: TextAlign.center),
                  )
                else
                  for (final card in shown)
                    _DiscCardRow(
                      card: card,
                      isSaved: savedIds.contains(card.id),
                      onToggleSave: () => _toggleSave(card, savedIds.contains(card.id)),
                      onTap: () => showCardDetailSheet(context, card: card),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The concept's disc-thumb is a flat placeholder color per card (no
/// media_assets/cover images exist yet, same deferred-upload precedent as
/// Milestone 2's cards) -- picked deterministically from a small fixed
/// palette so the same card always shows the same color across rebuilds.
const _thumbPalette = [Color(0xFFCFE2B0), Color(0xFFE9C7B8), Color(0xFFC9D6E0), Color(0xFFE0D3C9)];

class _DiscCardRow extends StatelessWidget {
  const _DiscCardRow({required this.card, required this.isSaved, required this.onToggleSave, required this.onTap});

  final DiscoverCard card;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbColor = _thumbPalette[card.id.hashCode.abs() % _thumbPalette.length];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: thumbColor, borderRadius: BorderRadius.circular(10))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (card.trainerDisplayName != null)
                    Text(card.trainerDisplayName!, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(card.difficulty, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? AppColors.lime : null),
              tooltip: 'Save',
              onPressed: onToggleSave,
            ),
          ],
        ),
      ),
    );
  }
}
