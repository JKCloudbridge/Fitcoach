import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../workout_cards/presentation/workout_cards_providers.dart';
import '../data/assign_habit_template_repository.dart';

/// Mirrors workout_cards/presentation/assign_card_sheet.dart exactly, minus
/// the start/due date pickers (habits has no such columns) -- reuses the
/// same `trainerActiveClientsProvider` that flow already built, per
/// CLAUDE.md's reuse instruction.
Future<void> showAssignHabitTemplateSheet(BuildContext context, {required String templateId, required String templateTitle}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AssignHabitTemplateSheet(templateId: templateId, templateTitle: templateTitle),
  );
}

class _AssignHabitTemplateSheet extends ConsumerStatefulWidget {
  const _AssignHabitTemplateSheet({required this.templateId, required this.templateTitle});

  final String templateId;
  final String templateTitle;

  @override
  ConsumerState<_AssignHabitTemplateSheet> createState() => _AssignHabitTemplateSheetState();
}

class _AssignHabitTemplateSheetState extends ConsumerState<_AssignHabitTemplateSheet> {
  String? _selectedClientId;
  bool _assigning = false;
  String? _error;

  Future<void> _assign() async {
    final clientId = _selectedClientId;
    if (clientId == null) {
      setState(() => _error = 'Pick a client first');
      return;
    }

    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      await ref.read(assignHabitTemplateRepositoryProvider).assign(templateId: widget.templateId, clientId: clientId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Habit assigned')));
      }
    } catch (e) {
      setState(() => _error = describeAssignHabitTemplateError(e));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(trainerActiveClientsProvider);

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Assign "${widget.templateTitle}"', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load your clients: $error'),
            data: (clients) {
              if (clients.isEmpty) {
                return const Text(
                  'No active clients yet. A coaching connection has to exist before you can assign a habit to someone -- see the manual steps doc for how to create one for testing.',
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedClientId,
                decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
                items: [
                  for (final client in clients)
                    DropdownMenuItem(value: client.clientId, child: Text(client.displayName ?? 'Unnamed client')),
                ],
                onChanged: _assigning ? null : (value) => setState(() => _selectedClientId = value),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _assigning ? null : _assign,
            child: _assigning
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : const Text('Assign'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
