import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/assignments/data/assignment_models.dart';

void main() {
  group('WorkoutAssignment.fromMap', () {
    test('reads joined card title and trainer display name', () {
      final assignment = WorkoutAssignment.fromMap({
        'id': 'assignment-1',
        'card_id': 'card-1',
        'trainer_id': 'trainer-1',
        'client_id': 'client-1',
        'source': 'trainer_assigned',
        'assigned_at': '2026-01-01T00:00:00Z',
        'status': 'active',
        'workout_cards': {'title': 'Lower Body Strength'},
        'trainer_profiles': {'display_name': 'Jordan Reyes'},
      });
      expect(assignment.cardTitle, 'Lower Body Strength');
      expect(assignment.trainerDisplayName, 'Jordan Reyes');
      expect(assignment.status, 'active');
    });

    test('defaults missing optional fields', () {
      final assignment = WorkoutAssignment.fromMap({
        'id': 'assignment-1',
        'card_id': 'card-1',
        'client_id': 'client-1',
        'assigned_at': '2026-01-01T00:00:00Z',
      });
      expect(assignment.source, 'trainer_assigned');
      expect(assignment.status, 'active');
      expect(assignment.startDate, isNull);
      expect(assignment.dueDate, isNull);
      expect(assignment.cardTitle, isNull);
    });
  });

  group('AssignmentExercise.fromMap', () {
    test('carries source_exercise_id for traceability back to the template', () {
      final exercise = AssignmentExercise.fromMap({
        'id': 'ae-1',
        'assignment_id': 'assignment-1',
        'source_exercise_id': 'ex-1',
        'order_index': 0,
        'name': 'Back Squat',
        'sets': 4,
        'reps': '6',
        'weight_kg': 70,
        'rest_seconds': 90,
      });
      expect(exercise.sourceExerciseId, 'ex-1');
      expect(exercise.sets, 4);
      expect(exercise.weightKg, 70);
    });
  });
}
