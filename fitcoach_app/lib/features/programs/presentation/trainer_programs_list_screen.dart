import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'programs_providers.dart';

const _billingSuffixes = {'monthly': '/mo', 'one_time': ' one-time'};

/// Trainer side program list -- mirrors workout_cards/presentation/
/// cards_list_screen.dart and habit_templates/presentation/
/// habit_templates_list_screen.dart exactly: embedded (not routed directly)
/// inside TrainerLibraryScreen's toggle, same fold-in this app has used for
/// every new trainer-authored content type since Milestone 4.5.
class TrainerProgramsListScreen extends ConsumerWidget {
  const TrainerProgramsListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(trainerProgramsProvider);

    final body = programsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load your programs: $error')),
      data: (programs) {
        if (programs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No programs yet. Build one from the Build tab.', textAlign: TextAlign.center),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(trainerProgramsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final program = programs[index];
              return Card(
                child: ListTile(
                  onTap: () => context.push('/trainer/cards/programs/${program.id}'),
                  title: Text(program.title),
                  subtitle: Text(
                    '${program.isFree ? 'Free' : '₹${program.priceInr.toStringAsFixed(0)}${_billingSuffixes[program.billingPeriod] ?? ''}'}'
                    '${program.isPublished ? '' : ' • Draft'}',
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Programs')), body: body);
  }
}
