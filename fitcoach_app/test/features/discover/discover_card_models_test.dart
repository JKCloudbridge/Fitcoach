import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/discover/data/discover_models.dart';

void main() {
  group('DiscoverCard.fromMap', () {
    test('defaults missing optional fields', () {
      final card = DiscoverCard.fromMap({
        'id': 'card-1',
        'trainer_id': 'trainer-1',
        'title': 'Foundations: Squat Technique',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(card.trainerDisplayName, isNull);
      expect(card.description, isNull);
      expect(card.tags, isEmpty);
      expect(card.difficulty, 'beginner');
    });

    test('reads populated fields including the joined trainer display name', () {
      final card = DiscoverCard.fromMap({
        'id': 'card-1',
        'trainer_id': 'trainer-1',
        'title': 'Foundations: Squat Technique',
        'description': 'A beginner-friendly squat progression',
        'tags': ['strength'],
        'difficulty': 'intermediate',
        'created_at': '2026-01-01T00:00:00Z',
        'trainer_profiles': {'display_name': 'Coach Elena Ruiz'},
      });
      expect(card.trainerDisplayName, 'Coach Elena Ruiz');
      expect(card.description, 'A beginner-friendly squat progression');
      expect(card.tags, ['strength']);
      expect(card.difficulty, 'intermediate');
    });
  });
}
