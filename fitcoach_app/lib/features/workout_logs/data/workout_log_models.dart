/// Hand-written model with fromMap -- no codegen, same convention as the
/// rest of the app.
class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.clientId,
    required this.assignmentExerciseId,
    required this.logDate,
    this.actualSets,
    this.actualReps,
    this.actualWeightKg,
    this.completed = false,
    this.perceivedEffort,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String assignmentExerciseId;
  final DateTime logDate;
  final int? actualSets;
  final String? actualReps;
  final num? actualWeightKg;
  final bool completed;
  final int? perceivedEffort;
  final String? notes;
  final DateTime createdAt;

  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    return WorkoutLog(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      assignmentExerciseId: map['assignment_exercise_id'] as String,
      logDate: DateTime.parse(map['log_date'] as String),
      actualSets: map['actual_sets'] as int?,
      actualReps: map['actual_reps'] as String?,
      actualWeightKg: map['actual_weight_kg'] as num?,
      completed: map['completed'] as bool? ?? false,
      perceivedEffort: map['perceived_effort'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
