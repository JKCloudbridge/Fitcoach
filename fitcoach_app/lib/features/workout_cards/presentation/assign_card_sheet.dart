import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/assign_workout_card_repository.dart';
import 'workout_cards_providers.dart';

Future<void> showAssignCardSheet(BuildContext context, {required String cardId, required String cardTitle}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AssignCardSheet(cardId: cardId, cardTitle: cardTitle),
  );
}

class _AssignCardSheet extends ConsumerStatefulWidget {
  const _AssignCardSheet({required this.cardId, required this.cardTitle});

  final String cardId;
  final String cardTitle;

  @override
  ConsumerState<_AssignCardSheet> createState() => _AssignCardSheetState();
}

class _AssignCardSheetState extends ConsumerState<_AssignCardSheet> {
  String? _selectedClientId;
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _assigning = false;
  String? _error;

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _dueDate = picked);
  }

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
      await ref.read(assignWorkoutCardRepositoryProvider).assign(
        cardId: widget.cardId,
        clientId: clientId,
        startDate: _startDate,
        dueDate: _dueDate,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card assigned')));
      }
    } catch (e) {
      setState(() => _error = describeAssignError(e));
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
          Text('Assign "${widget.cardTitle}"', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load your clients: $error'),
            data: (clients) {
              if (clients.isEmpty) {
                return const Text(
                  'No active clients yet. A coaching connection has to exist before you can assign a card to someone -- see the manual steps doc for how to create one for testing.',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _assigning ? null : () => _pickDate(isStart: true),
                  child: Text(_startDate == null ? 'Start date (optional)' : DateFormat.yMMMd().format(_startDate!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _assigning ? null : () => _pickDate(isStart: false),
                  child: Text(_dueDate == null ? 'Due date (optional)' : DateFormat.yMMMd().format(_dueDate!)),
                ),
              ),
            ],
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
