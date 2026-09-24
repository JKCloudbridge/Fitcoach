/// Hand-written models with fromMap -- no codegen, same convention as the
/// rest of the app.
class Habit {
  const Habit({
    required this.id,
    this.templateId,
    required this.clientId,
    this.trainerId,
    this.source = 'self_created',
    required this.title,
    required this.type,
    this.unit,
    this.targetValue,
    this.wearableMetricField,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.status = 'active',
    required this.createdAt,
  });

  final String id;
  final String? templateId;
  final String clientId;
  final String? trainerId;
  final String source; // 'trainer_assigned' | 'self_created'
  final String title;
  final String type; // 'binary' | 'quantity' | 'wearable_auto'
  final String? unit;
  final num? targetValue;
  final String? wearableMetricField;
  final int currentStreak;
  final int bestStreak;
  final String status; // 'active' | 'archived'
  final DateTime createdAt;

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      templateId: map['template_id'] as String?,
      clientId: map['client_id'] as String,
      trainerId: map['trainer_id'] as String?,
      source: map['source'] as String? ?? 'self_created',
      title: map['title'] as String,
      type: map['type'] as String,
      unit: map['unit'] as String?,
      targetValue: map['target_value'] as num?,
      wearableMetricField: map['wearable_metric_field'] as String?,
      currentStreak: map['current_streak'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
      status: map['status'] as String? ?? 'active',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.logDate,
    this.value,
    this.completed = false,
    this.source = 'manual',
    required this.createdAt,
  });

  final String id;
  final String habitId;
  final DateTime logDate;
  final num? value;
  final bool completed;
  final String source; // 'manual' | 'wearable_auto'
  final DateTime createdAt;

  factory HabitLog.fromMap(Map<String, dynamic> map) {
    return HabitLog(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      logDate: DateTime.parse(map['log_date'] as String),
      value: map['value'] as num?,
      completed: map['completed'] as bool? ?? false,
      source: map['source'] as String? ?? 'manual',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
