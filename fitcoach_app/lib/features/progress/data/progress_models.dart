/// A single weighted workout_logs row joined with its exercise's name, per
/// Milestone 4's "new personal record" card (max actual_weight_kg per
/// exercise name from workout_logs) -- uses Milestone 2's existing tables,
/// no new schema. Hand-written fromMap, same convention as the rest of the
/// app.
class WeightLogEntry {
  const WeightLogEntry({required this.exerciseName, required this.weightKg, required this.logDate});

  final String exerciseName;
  final num weightKg;
  final DateTime logDate;

  factory WeightLogEntry.fromMap(Map<String, dynamic> map) {
    final exercise = map['assignment_exercises'] as Map<String, dynamic>?;
    return WeightLogEntry(
      exerciseName: exercise?['name'] as String? ?? 'Exercise',
      weightKg: map['actual_weight_kg'] as num,
      logDate: DateTime.parse(map['log_date'] as String),
    );
  }
}
