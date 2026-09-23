/// Hand-written models with fromMap -- no codegen, same convention as
/// features/profile's and workout_cards' models.
class WorkoutAssignment {
  const WorkoutAssignment({
    required this.id,
    required this.cardId,
    this.trainerId,
    required this.clientId,
    this.relationshipId,
    required this.source,
    required this.assignedAt,
    this.startDate,
    this.dueDate,
    this.status = 'active',
    this.cardTitle,
    this.trainerDisplayName,
  });

  final String id;
  final String cardId;
  final String? trainerId;
  final String clientId;
  final String? relationshipId;
  final String source; // 'trainer_assigned' | 'self_saved'
  final DateTime assignedAt;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String status; // 'active' | 'completed' | 'archived'
  final String? cardTitle;
  final String? trainerDisplayName;

  factory WorkoutAssignment.fromMap(Map<String, dynamic> map) {
    final card = map['workout_cards'] as Map<String, dynamic>?;
    final trainer = map['trainer_profiles'] as Map<String, dynamic>?;
    return WorkoutAssignment(
      id: map['id'] as String,
      cardId: map['card_id'] as String,
      trainerId: map['trainer_id'] as String?,
      clientId: map['client_id'] as String,
      relationshipId: map['relationship_id'] as String?,
      source: map['source'] as String? ?? 'trainer_assigned',
      assignedAt: DateTime.parse(map['assigned_at'] as String),
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date'] as String) : null,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      status: map['status'] as String? ?? 'active',
      cardTitle: card?['title'] as String?,
      trainerDisplayName: trainer?['display_name'] as String?,
    );
  }
}

class AssignmentExercise {
  const AssignmentExercise({
    required this.id,
    required this.assignmentId,
    this.sourceExerciseId,
    required this.orderIndex,
    required this.name,
    required this.sets,
    required this.reps,
    this.weightKg,
    required this.restSeconds,
    this.notes,
  });

  final String id;
  final String assignmentId;
  final String? sourceExerciseId;
  final int orderIndex;
  final String name;
  final int sets;
  final String reps;
  final num? weightKg;
  final int restSeconds;
  final String? notes;

  factory AssignmentExercise.fromMap(Map<String, dynamic> map) {
    return AssignmentExercise(
      id: map['id'] as String,
      assignmentId: map['assignment_id'] as String,
      sourceExerciseId: map['source_exercise_id'] as String?,
      orderIndex: map['order_index'] as int? ?? 0,
      name: map['name'] as String,
      sets: map['sets'] as int? ?? 1,
      reps: map['reps'] as String? ?? '',
      weightKg: map['weight_kg'] as num?,
      restSeconds: map['rest_seconds'] as int? ?? 60,
      notes: map['notes'] as String?,
    );
  }
}
