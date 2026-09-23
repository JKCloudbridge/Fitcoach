/// Hand-written model with fromMap -- no codegen, same convention as the rest
/// of the app. A read-only projection of workout_cards for Discover's public
/// library list -- whether a given card is saved lives in a separate
/// saved_cards id set (discover_providers.dart's savedCardIdsProvider), not a
/// field on this model, since save state changes independently of the card
/// list itself.
class DiscoverCard {
  const DiscoverCard({
    required this.id,
    required this.trainerId,
    this.trainerDisplayName,
    required this.title,
    this.description,
    this.tags = const [],
    this.difficulty = 'beginner',
    required this.createdAt,
  });

  final String id;
  final String trainerId;
  final String? trainerDisplayName;
  final String title;
  final String? description;
  final List<String> tags;
  final String difficulty; // 'beginner' | 'intermediate' | 'advanced'
  final DateTime createdAt;

  factory DiscoverCard.fromMap(Map<String, dynamic> map) {
    final trainer = map['trainer_profiles'] as Map<String, dynamic>?;
    return DiscoverCard(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      trainerDisplayName: trainer?['display_name'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      difficulty: map['difficulty'] as String? ?? 'beginner',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
