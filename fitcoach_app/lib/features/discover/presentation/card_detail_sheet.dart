import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tag_pill.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../workout_cards/presentation/workout_cards_providers.dart';
import '../data/discover_models.dart';
import '../data/discover_repository.dart';
import '../data/follow_public_card_repository.dart';

/// Tapping a disc-card row opens this -- not shown in the concept HTML's
/// screenDiscover() (it only has a bookmark toggle), but Requirement 1 §6.6
/// still requires a way to actually call follow-public-card ("start this
/// program"), and the codebase already has this exact sheet-on-tap pattern
/// (workout_cards/presentation/assign_card_sheet.dart,
/// workout_logs/presentation/log_set_sheet.dart) -- reused here rather than
/// inventing a new interaction, per the user's own choice when asked.
Future<void> showCardDetailSheet(BuildContext context, {required DiscoverCard card}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CardDetailSheet(card: card),
  );
}

class _CardDetailSheet extends ConsumerStatefulWidget {
  const _CardDetailSheet({required this.card});

  final DiscoverCard card;

  @override
  ConsumerState<_CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends ConsumerState<_CardDetailSheet> {
  bool _starting = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await ref.read(followPublicCardRepositoryProvider).follow(cardId: widget.card.id);
      ref.invalidate(activeAssignmentProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started — check Today')));
      }
    } catch (e) {
      setState(() => _error = describeFollowError(e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(context: context, builder: (context) => const _ReportReasonDialog());
    if (reason == null || reason.trim().isEmpty) return;

    final reportedBy = ref.read(authProvider).userId;
    if (reportedBy == null) return;

    try {
      await ref.read(discoverRepositoryProvider).reportCard(cardId: widget.card.id, reportedBy: reportedBy, reason: reason.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported — thanks, our team will review it')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send report: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(cardWithExercisesProvider(widget.card.id));

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.card.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (widget.card.trainerDisplayName != null) Text('by ${widget.card.trainerDisplayName}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [TagPill(widget.card.difficulty), for (final tag in widget.card.tags) TagPill(tag)],
          ),
          if (widget.card.description != null && widget.card.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(widget.card.description!),
          ],
          const SizedBox(height: 16),
          exercisesAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
            error: (error, _) => Text('Could not load exercises: $error'),
            data: (result) {
              final (_, exercises) = result;
              if (exercises.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final exercise in exercises)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${exercise.name} — ${exercise.sets} × ${exercise.reps}'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _starting ? null : _start,
            child: _starting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : const Text('Start this program'),
          ),
          TextButton(onPressed: _starting ? null : _report, child: const Text('Report this card')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// The "basic moderation flag" this milestone's own scope calls for -- a
/// single reason field, not a full moderation UI (moderate-card/
/// moderation-api stay deferred per Plan.md's open decisions).
class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog();

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report this card'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'What\'s wrong with it?', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Submit')),
      ],
    );
  }
}
