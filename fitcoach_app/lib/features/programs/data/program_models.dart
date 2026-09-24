/// Hand-written models with fromMap -- no codegen, same convention as the
/// rest of the app. Program mirrors WorkoutCard/HabitTemplate's own shape
/// (per migration 023's own "bundles a workout_card and habit_templates"
/// design, Requirement 1 §11.1-11.2) -- bundled habit titles/ids come from a
/// nested `program_habits(habit_templates(...))` select, same embedding
/// style DiscoverCard uses for trainer_profiles.
class Program {
  const Program({
    required this.id,
    required this.trainerId,
    this.trainerDisplayName,
    this.orgId,
    required this.title,
    this.description,
    required this.priceInr,
    this.billingPeriod = 'one_time',
    this.workoutCardId,
    this.workoutCardTitle,
    this.isPublished = false,
    this.moderationStatus = 'approved',
    required this.createdAt,
    this.habitTemplateIds = const [],
    this.habitTemplateTitles = const [],
  });

  final String id;
  final String trainerId;
  final String? trainerDisplayName;
  final String? orgId;
  final String title;
  final String? description;
  final num priceInr;
  final String billingPeriod; // 'monthly' | 'one_time'
  final String? workoutCardId;
  final String? workoutCardTitle;
  final bool isPublished;
  final String moderationStatus;
  final DateTime createdAt;
  final List<String> habitTemplateIds;
  final List<String> habitTemplateTitles;

  bool get isFree => priceInr <= 0;

  factory Program.fromMap(Map<String, dynamic> map) {
    final trainer = map['trainer_profiles'] as Map<String, dynamic>?;
    final workoutCard = map['workout_cards'] as Map<String, dynamic>?;
    final habitTemplates = ((map['program_habits'] as List<dynamic>?) ?? const [])
        .map((row) => (row as Map<String, dynamic>)['habit_templates'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .toList();
    return Program(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      trainerDisplayName: trainer?['display_name'] as String?,
      orgId: map['org_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      priceInr: map['price_inr'] as num? ?? 0,
      billingPeriod: map['billing_period'] as String? ?? 'one_time',
      workoutCardId: map['workout_card_id'] as String?,
      workoutCardTitle: workoutCard?['title'] as String?,
      isPublished: map['is_published'] as bool? ?? false,
      moderationStatus: map['moderation_status'] as String? ?? 'approved',
      createdAt: DateTime.parse(map['created_at'] as String),
      habitTemplateIds: habitTemplates.map((ht) => ht['id'] as String).toList(),
      habitTemplateTitles: habitTemplates.map((ht) => ht['title'] as String).toList(),
    );
  }
}

/// One row from `program_subscriptions` (migration 024), per Requirement 1
/// §11.3. Only ever created by subscribe_program() (migration 028) --
/// [program] is populated when fetched via
/// ProgramSubscriptionsRepository.fetchMySubscriptions' embedded select,
/// null when this model is built from a bare program_subscriptions row.
class ProgramSubscription {
  const ProgramSubscription({
    required this.id,
    required this.clientId,
    required this.programId,
    required this.status,
    required this.pricePaidInr,
    required this.startedAt,
    this.currentPeriodEnd,
    this.program,
  });

  final String id;
  final String clientId;
  final String programId;
  final String status; // 'active' | 'canceled' | 'past_due'
  final num pricePaidInr;
  final DateTime startedAt;
  final DateTime? currentPeriodEnd;
  final Program? program;

  factory ProgramSubscription.fromMap(Map<String, dynamic> map) {
    final programMap = map['programs'] as Map<String, dynamic>?;
    return ProgramSubscription(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      programId: map['program_id'] as String,
      status: map['status'] as String,
      pricePaidInr: map['price_paid_inr'] as num? ?? 0,
      startedAt: DateTime.parse(map['started_at'] as String),
      currentPeriodEnd: map['current_period_end'] != null ? DateTime.parse(map['current_period_end'] as String) : null,
      program: programMap != null ? Program.fromMap(programMap) : null,
    );
  }
}
