import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../assignments/data/assignment_models.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/workout_log_models.dart';
import '../data/workout_logs_repository.dart';

Future<void> showLogSetSheet(BuildContext context, {required AssignmentExercise exercise, WorkoutLog? existingLog}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LogSetSheet(exercise: exercise, existingLog: existingLog),
  );
}

class _LogSetSheet extends ConsumerStatefulWidget {
  const _LogSetSheet({required this.exercise, this.existingLog});

  final AssignmentExercise exercise;
  final WorkoutLog? existingLog;

  @override
  ConsumerState<_LogSetSheet> createState() => _LogSetSheetState();
}

class _LogSetSheetState extends ConsumerState<_LogSetSheet> {
  late final _setsController = TextEditingController(text: (widget.existingLog?.actualSets ?? widget.exercise.sets).toString());
  late final _repsController = TextEditingController(text: widget.existingLog?.actualReps ?? widget.exercise.reps);
  late final _weightController = TextEditingController(
    text: (widget.existingLog?.actualWeightKg ?? widget.exercise.weightKg)?.toString() ?? '',
  );
  late final _notesController = TextEditingController(text: widget.existingLog?.notes ?? '');
  int? _perceivedEffort;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _perceivedEffort = widget.existingLog?.perceivedEffort;
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final clientId = ref.read(authProvider).userId;
    if (clientId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(workoutLogsRepositoryProvider).logSet(
        existingLogId: widget.existingLog?.id,
        clientId: clientId,
        assignmentExerciseId: widget.exercise.id,
        actualSets: int.tryParse(_setsController.text.trim()) ?? widget.exercise.sets,
        actualReps: _repsController.text.trim(),
        actualWeightKg: num.tryParse(_weightController.text.trim()),
        perceivedEffort: _perceivedEffort,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      ref.invalidate(todayLogsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not log this set: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.exercise.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Planned: ${widget.exercise.sets} × ${widget.exercise.reps}${widget.exercise.weightKg != null ? ' @ ${widget.exercise.weightKg}kg' : ''}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _setsController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sets', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _repsController,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Reps', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Perceived effort${_perceivedEffort != null ? ' — $_perceivedEffort/10' : ' (optional)'}'),
          Slider(
            value: (_perceivedEffort ?? 0).toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: _perceivedEffort?.toString() ?? '—',
            onChanged: _saving ? null : (value) => setState(() => _perceivedEffort = value == 0 ? null : value.round()),
          ),
          TextFormField(
            controller: _notesController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : Text(widget.existingLog == null ? 'Log this set' : 'Update log'),
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
