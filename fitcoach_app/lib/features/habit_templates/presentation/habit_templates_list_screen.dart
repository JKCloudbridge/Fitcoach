import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'assign_habit_template_sheet.dart';
import 'habit_templates_providers.dart';

const _visibilityLabels = {'public': 'Public', 'private': 'Private', 'gym_only': 'Gym'};
const _typeLabels = {'binary': 'Yes/No', 'quantity': 'Quantity', 'wearable_auto': 'Wearable'};

/// Mirrors workout_cards/presentation/cards_list_screen.dart exactly --
/// embedded (not routed directly) inside TrainerLibraryScreen's toggle.
class HabitTemplatesListScreen extends ConsumerWidget {
  const HabitTemplatesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(trainerHabitTemplatesProvider);

    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load your habit templates: $error')),
      data: (templates) {
        if (templates.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No habit templates yet. Build your first one from the Build tab.', textAlign: TextAlign.center),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(trainerHabitTemplatesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                child: ListTile(
                  onTap: () => context.push('/trainer/cards/templates/${template.id}'),
                  title: Text(template.title),
                  subtitle: Text(
                    '${_visibilityLabels[template.visibility] ?? template.visibility} • ${_typeLabels[template.type] ?? template.type}'
                    '${template.isPublished ? '' : ' • Draft'}',
                  ),
                  trailing: TextButton(
                    onPressed: () => showAssignHabitTemplateSheet(context, templateId: template.id, templateTitle: template.title),
                    child: const Text('Assign'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
