import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/workout_cards/data/workout_card_models.dart';

void main() {
  group('WorkoutCard.fromMap', () {
    test('defaults missing optional fields', () {
      final card = WorkoutCard.fromMap({
        'id': 'card-1',
        'trainer_id': 'trainer-1',
        'title': 'Lower Body Strength',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(card.visibility, 'private');
      expect(card.difficulty, 'beginner');
      expect(card.isPublished, isFalse);
      expect(card.moderationStatus, 'approved');
      expect(card.tags, isEmpty);
      expect(card.exerciseCount, 0);
    });

    test('reads populated fields and counts nested exercises', () {
      final card = WorkoutCard.fromMap({
        'id': 'card-1',
        'trainer_id': 'trainer-1',
        'title': 'Lower Body Strength',
        'visibility': 'public',
        'difficulty': 'advanced',
        'is_published': true,
        'tags': ['legs', 'strength'],
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
        'exercises': [
          {'id': 'ex-1'},
          {'id': 'ex-2'},
        ],
      });
      expect(card.visibility, 'public');
      expect(card.difficulty, 'advanced');
      expect(card.isPublished, isTrue);
      expect(card.tags, ['legs', 'strength']);
      expect(card.exerciseCount, 2);
    });
  });

  group('Exercise.fromMap / toInsertMap', () {
    test('round-trips through fromMap and toInsertMap', () {
      final exercise = Exercise.fromMap({
        'id': 'ex-1',
        'card_id': 'card-1',
        'name': 'Back Squat',
        'order_index': 0,
        'sets': 4,
        'reps': '6',
        'weight_kg': 70,
        'rest_seconds': 90,
        'notes': 'Warm up first',
      });
      expect(exercise.name, 'Back Squat');
      expect(exercise.sets, 4);
      expect(exercise.weightKg, 70);

      final insertMap = exercise.toInsertMap('card-2');
      expect(insertMap['card_id'], 'card-2');
      expect(insertMap['name'], 'Back Squat');
      expect(insertMap['order_index'], 0);
    });

    test('defaults missing optional fields', () {
      final exercise = Exercise.fromMap({'id': 'ex-1', 'name': 'Push Up'});
      expect(exercise.sets, 1);
      expect(exercise.reps, '');
      expect(exercise.weightKg, isNull);
      expect(exercise.restSeconds, 60);
    });

    test('copyWith reassigns orderIndex without touching other fields', () {
      const exercise = Exercise(name: 'Row', orderIndex: 5, sets: 3, reps: '10', restSeconds: 60);
      final moved = exercise.copyWith(orderIndex: 1);
      expect(moved.orderIndex, 1);
      expect(moved.name, 'Row');
      expect(moved.sets, 3);
    });
  });
}
