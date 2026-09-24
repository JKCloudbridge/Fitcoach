import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tag_pill.dart';
import 'program_detail_sheet.dart';
import 'programs_providers.dart';

/// Client "Programs" mode of Discover (Requirement 1 §11) -- the paid
/// marketplace listing, folded into DiscoverScreen as a second
/// SegmentedButton mode alongside the existing free-card browsing, same
/// "toggle between two content types inside one tab" convention
/// TrainerLibraryScreen/TrainerBuildScreen already use for cards vs. habit
/// templates. No concept HTML reference for this screen (confirmed in this
/// milestone's own scoping pass -- the concept's only "Programs" mention is
/// Discover's existing tagline) -- designed fresh, following the same
/// list-row convention as DiscoverScreen's own _DiscCardRow.
class ProgramsListScreen extends ConsumerWidget {
  const ProgramsListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(publicProgramsProvider);
    final activeIds = ref.watch(myActiveProgramIdsProvider).maybeWhen(data: (ids) => ids, orElse: () => const <String>{});

    final body = programsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load programs: $error')),
      data: (programs) {
        if (programs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('No programs published yet — check back soon.', textAlign: TextAlign.center),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(publicProgramsProvider);
            ref.invalidate(myProgramSubscriptionsProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final program = programs[index];
              return Card(
                child: ListTile(
                  onTap: () => showProgramDetailSheet(context, program: program),
                  title: Text(program.title),
                  subtitle: Text(
                    [
                      if (program.trainerDisplayName != null) program.trainerDisplayName!,
                      program.isFree
                          ? 'Free'
                          : '₹${program.priceInr.toStringAsFixed(0)}${program.billingPeriod == 'monthly' ? '/mo' : ''}',
                    ].join(' · '),
                  ),
                  trailing: activeIds.contains(program.id) ? const TagPill('Subscribed') : const Icon(Icons.chevron_right),
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
