import '../data/discover_models.dart';

/// Pure function, same convention as assignments/utils/
/// merge_exercises_with_logs.dart -- keeps the filter-chip logic unit-testable
/// without a widget test. 'all' (the concept's default chip) returns every
/// card; any other key filters by tag membership, matching the concept's
/// `c.tag === filter` -- except workout_cards.tags is an array, not a single
/// value, so this checks `tags.contains(filter)` rather than equality.
List<DiscoverCard> filterDiscoverCards(List<DiscoverCard> cards, String filter) {
  if (filter == 'all') return cards;
  return cards.where((card) => card.tags.contains(filter)).toList();
}
