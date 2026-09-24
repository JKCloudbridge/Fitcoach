import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../habit_templates/data/habit_template_models.dart';
import '../data/habits_repository.dart';
import 'habits_providers.dart';

const _createModeOptions = [
  (value: 'scratch', label: 'From scratch'),
  (value: 'template', label: 'Browse templates'),
];

/// Two ways in, both direct-RLS single-owner writes (see
/// habits_repository.dart's own header for why neither needs an Edge
/// Function): building a habit from scratch (`template_id = null`), or
/// adopting a public habit_template someone else authored (`template_id`
/// set, `source` still `'self_created'` -- the client is the one acting).
/// The trainer-push path (Milestone 4.5's habits-api) is a *different*
/// entry point entirely (habit_templates/presentation/
/// assign_habit_template_sheet.dart, reached from the trainer side), not
/// offered here. Invoked from the Progress screen's habits section, not
/// Today -- Today is where a client checks habits off, Progress is where
/// they're managed, per the user's own "Both" answer when asked where habit
/// tracking should live.
Future<void> showCreateHabitSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CreateHabitSheet(),
  );
}

class _CreateHabitSheet extends StatefulWidget {
  const _CreateHabitSheet();

  @override
  State<_CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends State<_CreateHabitSheet> {
  String _mode = 'scratch';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New habit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [for (final option in _createModeOptions) ButtonSegment(value: option.value, label: Text(option.label))],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 16),
          if (_mode == 'scratch') const _ScratchHabitForm() else const _TemplateBrowser(),
        ],
      ),
    );
  }
}

class _ScratchHabitForm extends ConsumerStatefulWidget {
  const _ScratchHabitForm();

  @override
  ConsumerState<_ScratchHabitForm> createState() => _ScratchHabitFormState();
}

class _ScratchHabitFormState extends ConsumerState<_ScratchHabitForm> {
  final _titleController = TextEditingController();
  final _unitController = TextEditingController();
  final _targetController = TextEditingController();
  String _type = 'binary';

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final clientId = ref.read(authProvider).userId;
    final title = _titleController.text.trim();
    if (clientId == null || title.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(habitsRepositoryProvider).createHabit(
        clientId: clientId,
        title: title,
        type: _type,
        unit: _type == 'quantity' && _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : null,
        targetValue: _type == 'quantity' ? num.tryParse(_targetController.text.trim()) : null,
      );
      ref.invalidate(activeHabitsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not create habit: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _titleController,
          enabled: !_saving,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Drink water, Sleep 8 hours'),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'binary', label: Text('Yes / No')),
            ButtonSegment(value: 'quantity', label: Text('Quantity')),
          ],
          selected: {_type},
          onSelectionChanged: _saving ? null : (selection) => setState(() => _type = selection.first),
        ),
        if (_type == 'quantity') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _targetController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Unit', hintText: 'glasses, g protein', isDense: true),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
              : const Text('Create habit'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _TemplateBrowser extends ConsumerStatefulWidget {
  const _TemplateBrowser();

  @override
  ConsumerState<_TemplateBrowser> createState() => _TemplateBrowserState();
}

class _TemplateBrowserState extends ConsumerState<_TemplateBrowser> {
  String? _adoptingTemplateId;
  String? _error;

  Future<void> _adopt(HabitTemplate template) async {
    final clientId = ref.read(authProvider).userId;
    if (clientId == null) return;

    setState(() {
      _adoptingTemplateId = template.id;
      _error = null;
    });
    try {
      await ref.read(habitsRepositoryProvider).adoptTemplate(clientId: clientId, template: template);
      ref.invalidate(activeHabitsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not add this habit: $e');
    } finally {
      if (mounted) setState(() => _adoptingTemplateId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(publicHabitTemplatesProvider);
    return SizedBox(
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Could not load templates: $error')),
              data: (templates) {
                if (templates.isEmpty) {
                  return const Center(child: Text('No public habit templates yet.', textAlign: TextAlign.center));
                }
                return ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final adopting = _adoptingTemplateId == template.id;
                    return Card(
                      child: ListTile(
                        title: Text(template.title),
                        subtitle: template.trainerDisplayName != null ? Text('by ${template.trainerDisplayName}', maxLines: 1) : null,
                        trailing: TextButton(
                          onPressed: _adoptingTemplateId != null ? null : () => _adopt(template),
                          child: adopting
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Add'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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
