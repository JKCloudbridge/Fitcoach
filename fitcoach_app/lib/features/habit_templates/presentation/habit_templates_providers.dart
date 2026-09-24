import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/habit_template_models.dart';
import '../data/habit_templates_repository.dart';

final trainerHabitTemplatesProvider = FutureProvider.autoDispose<List<HabitTemplate>>((ref) async {
  final trainerId = ref.watch(authProvider.select((s) => s.userId));
  if (trainerId == null) return const [];
  return ref.watch(habitTemplatesRepositoryProvider).fetchTrainerTemplates(trainerId);
});

final habitTemplateProvider = FutureProvider.autoDispose.family<HabitTemplate, String>((ref, templateId) {
  return ref.watch(habitTemplatesRepositoryProvider).fetchTemplate(templateId);
});
