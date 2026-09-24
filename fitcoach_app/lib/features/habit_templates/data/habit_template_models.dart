/// Hand-written model with fromMap -- no codegen, same convention as the
/// rest of the app. Mirrors WorkoutCard's shape (workout_cards/data/
/// workout_card_models.dart), per migration 014's own "mirrors workout_cards"
/// design.
class HabitTemplate {
  const HabitTemplate({
    required this.id,
    required this.trainerId,
    this.trainerDisplayName,
    this.orgId,
    required this.title,
    this.description,
    required this.type,
    this.unit,
    this.defaultTargetValue,
    this.wearableMetricField,
    this.visibility = 'private',
    this.isPublished = false,
    this.moderationStatus = 'approved',
    required this.createdAt,
  });

  final String id;
  final String trainerId;
  final String? trainerDisplayName;
  final String? orgId;
  final String title;
  final String? description;
  final String type; // 'binary' | 'quantity' | 'wearable_auto'
  final String? unit;
  final num? defaultTargetValue;
  final String? wearableMetricField;
  final String visibility; // 'public' | 'private' | 'gym_only'
  final bool isPublished;
  final String moderationStatus;
  final DateTime createdAt;

  factory HabitTemplate.fromMap(Map<String, dynamic> map) {
    final trainer = map['trainer_profiles'] as Map<String, dynamic>?;
    return HabitTemplate(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      trainerDisplayName: trainer?['display_name'] as String?,
      orgId: map['org_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      type: map['type'] as String,
      unit: map['unit'] as String?,
      defaultTargetValue: map['default_target_value'] as num?,
      wearableMetricField: map['wearable_metric_field'] as String?,
      visibility: map['visibility'] as String? ?? 'private',
      isPublished: map['is_published'] as bool? ?? false,
      moderationStatus: map['moderation_status'] as String? ?? 'approved',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
