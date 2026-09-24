import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/program_models.dart';
import '../data/subscribe_program_repository.dart';
import 'programs_providers.dart';

/// Tapping a program row opens this -- same sheet-on-tap pattern as
/// discover/presentation/card_detail_sheet.dart (assign_card_sheet.dart,
/// log_set_sheet.dart), reused rather than inventing a new interaction for
/// this milestone's own no-mockup screens, same call Milestone 6/7 made.
Future<void> showProgramDetailSheet(BuildContext context, {required Program program}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ProgramDetailSheet(program: program),
  );
}

class _ProgramDetailSheet extends ConsumerStatefulWidget {
  const _ProgramDetailSheet({required this.program});

  final Program program;

  @override
  ConsumerState<_ProgramDetailSheet> createState() => _ProgramDetailSheetState();
}

class _ProgramDetailSheetState extends ConsumerState<_ProgramDetailSheet> {
  bool _subscribing = false;
  String? _error;

  Future<void> _subscribe() async {
    setState(() {
      _subscribing = true;
      _error = null;
    });
    try {
      await ref.read(subscribeProgramRepositoryProvider).subscribe(programId: widget.program.id);
      ref.invalidate(myProgramSubscriptionsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscribed — check My Programs')));
      }
    } catch (e) {
      setState(() => _error = describeSubscribeProgramError(e));
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final activeIds = ref.watch(myActiveProgramIdsProvider).maybeWhen(data: (ids) => ids, orElse: () => const <String>{});
    final alreadySubscribed = activeIds.contains(program.id);

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(program.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (program.trainerDisplayName != null) Text('by ${program.trainerDisplayName}'),
          const SizedBox(height: 8),
          Text(
            program.isFree
                ? 'Free'
                : '₹${program.priceInr.toStringAsFixed(0)}${program.billingPeriod == 'monthly' ? '/month' : ' one-time'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (program.description != null && program.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(program.description!),
          ],
          if (program.workoutCardTitle != null || program.habitTemplateTitles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Includes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (program.workoutCardTitle != null) Text('Workout card: ${program.workoutCardTitle}'),
            for (final title in program.habitTemplateTitles) Text('Habit: $title'),
          ],
          const SizedBox(height: 16),
          if (alreadySubscribed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("You're already subscribed to this program.", textAlign: TextAlign.center),
            )
          else
            FilledButton(
              onPressed: _subscribing ? null : _subscribe,
              child: _subscribing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                  : Text(program.isFree ? 'Subscribe (free)' : 'Subscribe'),
            ),
          const SizedBox(height: 8),
          const Text(
            'No payment gateway is wired up yet -- subscribing activates access immediately for testing. '
            'Real billing is a pending follow-up (see Milestone 8 manual steps).',
            style: TextStyle(fontSize: 11.5, color: AppColors.inkSoftLight),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
