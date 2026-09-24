import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/habit_template_models.dart';
import '../data/habit_templates_repository.dart';
import 'habit_templates_providers.dart';

const _visibilityOptions = [
  (value: 'private', label: 'Private'),
  (value: 'gym_only', label: 'Gym'),
  (value: 'public', label: 'Public'),
];

// 'wearable_auto' is deliberately not offered here -- sync-wearable-data
// (Milestone 5) is what would ever complete one, and that doesn't exist yet.
// The schema/RLS already allow the value (migration 014's own "schema-ready,
// not wired up" precedent); this builder just doesn't expose it.
const _typeOptions = [
  (value: 'binary', label: 'Yes / No'),
  (value: 'quantity', label: 'Quantity'),
];

/// Create (templateId == null) or edit (templateId != null) a habit
/// template. Mirrors workout_cards/presentation/build_session_screen.dart's
/// shape, minus the exercises sub-list -- a habit_templates row has no child
/// table to manage, it's a single flat form. No mockup precedent for this
/// screen (see Milestone 4.5.md's known gaps) -- laid out to match
/// BuildSessionScreen's own field conventions rather than the concept HTML,
/// since there's nothing in the concept to match.
class BuildHabitTemplateScreen extends ConsumerStatefulWidget {
  const BuildHabitTemplateScreen({super.key, this.templateId, this.embedded = false});

  final String? templateId;

  /// True when a parent screen already provides the Scaffold + AppBar --
  /// only meaningful for the create case (templateId == null);
  /// TrainerBuildScreen embeds this alongside BuildSessionScreen behind a
  /// toggle. The edit case (reached via its own pushed route) always gets
  /// its own Scaffold, same as BuildSessionScreen's shape.
  final bool embedded;

  @override
  ConsumerState<BuildHabitTemplateScreen> createState() => _BuildHabitTemplateScreenState();
}

class _BuildHabitTemplateScreenState extends ConsumerState<BuildHabitTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController();
  final _targetController = TextEditingController();

  String _type = 'binary';
  String _visibility = 'private';
  bool _isPublished = false;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.templateId != null;

  void _initFrom(HabitTemplate template) {
    if (_initialized) return;
    _titleController.text = template.title;
    _descriptionController.text = template.description ?? '';
    _unitController.text = template.unit ?? '';
    _targetController.text = template.defaultTargetValue?.toString() ?? '';
    _type = template.type == 'wearable_auto' ? 'binary' : template.type;
    _visibility = template.visibility;
    _isPublished = template.isPublished;
    _initialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final trainerId = ref.read(authProvider).userId;
    if (trainerId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(habitTemplatesRepositoryProvider);
      final unit = _type == 'quantity' && _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : null;
      final target = _type == 'quantity' ? num.tryParse(_targetController.text.trim()) : null;

      if (_isEditing) {
        await repository.updateTemplate(
          templateId: widget.templateId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _type,
          unit: unit,
          defaultTargetValue: target,
          visibility: _visibility,
          isPublished: _isPublished,
        );
        ref.invalidate(habitTemplateProvider(widget.templateId!));
      } else {
        await repository.createTemplate(
          trainerId: trainerId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _type,
          unit: unit,
          defaultTargetValue: target,
          visibility: _visibility,
          isPublished: _isPublished,
        );
      }
      ref.invalidate(trainerHabitTemplatesProvider);

      if (!mounted) return;
      if (_isEditing) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Habit template saved')));
        setState(() {
          _titleController.clear();
          _descriptionController.clear();
          _unitController.clear();
          _targetController.clear();
          _type = 'binary';
          _visibility = 'private';
          _isPublished = false;
        });
      }
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_isEditing ? 'Edit habit template' : 'New habit template', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Drink water, Sleep 8 hours', border: OutlineInputBorder()),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a title' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            enabled: !_saving,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [for (final option in _typeOptions) ButtonSegment(value: option.value, label: Text(option.label))],
            selected: {_type},
            onSelectionChanged: _saving ? null : (selection) => setState(() => _type = selection.first),
          ),
          if (_type == 'quantity') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _targetController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Default target', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Unit', hintText: 'glasses, g protein', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [for (final option in _visibilityOptions) ButtonSegment(value: option.value, label: Text(option.label))],
            selected: {_visibility},
            onSelectionChanged: _saving ? null : (selection) => setState(() => _visibility = selection.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Published'),
            subtitle: const Text('Draft templates are only visible to you'),
            value: _isPublished,
            onChanged: _saving ? null : (value) => setState(() => _isPublished = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : const Text('Save'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      if (widget.embedded) return _buildForm();
      return Scaffold(appBar: AppBar(title: const Text('Build a habit template')), body: _buildForm());
    }

    final templateAsync = ref.watch(habitTemplateProvider(widget.templateId!));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit habit template')),
      body: templateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load this template: $error')),
        data: (template) {
          _initFrom(template);
          return _buildForm();
        },
      ),
    );
  }
}
