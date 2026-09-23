import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/discover/data/discover_models.dart';
import 'package:fitcoach_app/features/discover/utils/filter_discover_cards.dart';

DiscoverCard _card(String id, List<String> tags) {
  return DiscoverCard(id: id, trainerId: 'trainer-1', title: id, tags: tags, createdAt: DateTime(2026, 1, 1));
}

void main() {
  group('filterDiscoverCards', () {
    final cards = [
      _card('c1', ['strength']),
      _card('c2', ['strength', 'conditioning']),
      _card('c3', ['mobility']),
    ];

    test('"all" returns every card unchanged', () {
      expect(filterDiscoverCards(cards, 'all'), cards);
    });

    test('filters to cards whose tags contain the selected filter', () {
      final result = filterDiscoverCards(cards, 'strength');
      expect(result.map((c) => c.id), ['c1', 'c2']);
    });

    test('returns an empty list when nothing matches', () {
      expect(filterDiscoverCards(cards, 'conditioning-only'), isEmpty);
    });
  });
}
