/// Hand-written models with fromMap -- no codegen, same convention as
/// features/profile's models.
class WorkoutCard {
  const WorkoutCard({
    required this.id,
    required this.trainerId,
    this.orgId,
    required this.title,
    this.description,
    this.visibility = 'private',
    this.tags = const [],
    this.difficulty = 'beginner',
    this.isPublished = false,
    this.moderationStatus = 'approved',
    required this.createdAt,
    required this.updatedAt,
    this.exerciseCount = 0,
  });

  final String id;
  final String trainerId;
  final String? orgId;
  final String title;
  final String? description;
  final String visibility; // 'public' | 'private' | 'gym_only'
  final List<String> tags;
  final String difficulty; // 'beginner' | 'intermediate' | 'advanced'
  final bool isPublished;
  final String moderationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int exerciseCount;

  factory WorkoutCard.fromMap(Map<String, dynamic> map) {
    final exercises = map['exercises'] as List<dynamic>?;
    return WorkoutCard(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      orgId: map['org_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      visibility: map['visibility'] as String? ?? 'private',
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      difficulty: map['difficulty'] as String? ?? 'beginner',
      isPublished: map['is_published'] as bool? ?? false,
      moderationStatus: map['moderation_status'] as String? ?? 'approved',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      exerciseCount: exercises?.length ?? 0,
    );
  }
}

class Exercise {
  const Exercise({
    this.id,
    this.cardId,
    required this.name,
    required this.orderIndex,
    required this.sets,
    required this.reps,
    this.weightKg,
    required this.restSeconds,
    this.notes,
  });

  final String? id; // null for a not-yet-saved row in the builder
  final String? cardId;
  final String name;
  final int orderIndex;
  final int sets;
  final String reps;
  final num? weightKg;
  final int restSeconds;
  final String? notes;

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      cardId: map['card_id'] as String?,
      name: map['name'] as String,
      orderIndex: map['order_index'] as int? ?? 0,
      sets: map['sets'] as int? ?? 1,
      reps: map['reps'] as String? ?? '',
      weightKg: map['weight_kg'] as num?,
      restSeconds: map['rest_seconds'] as int? ?? 60,
      notes: map['notes'] as String?,
    );
  }

  Exercise copyWith({String? name, int? orderIndex, int? sets, String? reps, num? weightKg, int? restSeconds, String? notes}) {
    return Exercise(
      id: id,
      cardId: cardId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toInsertMap(String cardId) => {
    'card_id': cardId,
    'name': name,
    'order_index': orderIndex,
    'sets': sets,
    'reps': reps,
    'weight_kg': weightKg,
    'rest_seconds': restSeconds,
    'notes': notes,
  };
}
