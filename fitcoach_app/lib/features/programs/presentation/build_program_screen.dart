import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../habit_templates/data/habit_template_models.dart';
import '../../habit_templates/presentation/habit_templates_providers.dart';
import '../../workout_cards/data/workout_card_models.dart';
import '../../workout_cards/presentation/workout_cards_providers.dart';
import '../data/program_models.dart';
import '../data/programs_repository.dart';
import 'programs_providers.dart';

const _billingOptions = [
  (value: 'one_time', label: 'One-time'),
  (value: 'monthly', label: 'Monthly'),
];

/// Trainer "build a program" -- bundle an existing workout_card + zero or
/// more existing habit_templates, set a price, publish, per Requirement 1
/// §11.1-11.2. Unlike BuildSessionScreen/BuildHabitTemplateScreen (which
/// author new exercises/habit fields from scratch), this screen only
/// *selects* among a trainer's already-existing cards/templates -- a program
/// doesn't own its own exercise or habit content, it bundles content that
/// already exists elsewhere. No concept HTML reference (confirmed this
/// milestone -- same "design it yourself" situation Milestone 6/7 were in).
class BuildProgramScreen extends ConsumerStatefulWidget {
  const BuildProgramScreen({super.key, this.programId, this.embedded = false});

  final String? programId;

  /// True when a parent screen already provides the Scaffold + AppBar --
  /// TrainerBuildScreen embeds this alongside BuildSessionScreen/
  /// BuildHabitTemplateScreen behind a toggle. Only meaningful for the
  /// create case (programId == null), same convention as those two screens.
  final bool embedded;

  @override
  ConsumerState<BuildProgramScreen> createState() => _BuildProgramScreenState();
}

class _BuildProgramScreenState extends ConsumerState<BuildProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _selectedHabitTemplateIds = <String>{};

  String _billingPeriod = 'one_time';
  String? _workoutCardId;
  bool _isPublished = false;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.programId != null;

  void _initFrom(Program program) {
    if (_initialized) return;
    _titleController.text = program.title;
    _descriptionController.text = program.description ?? '';
    _priceController.text = program.priceInr.toStringAsFixed(0);
    _billingPeriod = program.billingPeriod;
    _workoutCardId = program.workoutCardId;
    _isPublished = program.isPublished;
    _selectedHabitTemplateIds.addAll(program.habitTemplateIds);
    _initialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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
      final repository = ref.read(programsRepositoryProvider);
      final priceInr = num.tryParse(_priceController.text.trim()) ?? 0;
      final programId =
          widget.programId ??
          await repository.createProgram(
            trainerId: trainerId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            priceInr: priceInr,
            billingPeriod: _billingPeriod,
            workoutCardId: _workoutCardId,
            isPublished: _isPublished,
          );
      if (_isEditing) {
        await repository.updateProgram(
          programId: programId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priceInr: priceInr,
          billingPeriod: _billingPeriod,
          workoutCardId: _workoutCardId,
          isPublished: _isPublished,
        );
      }
      await repository.replaceProgramHabits(programId, _selectedHabitTemplateIds.toList());

      ref.invalidate(trainerProgramsProvider);
      if (widget.programId != null) ref.invalidate(programWithHabitsProvider(widget.programId!));

      if (!mounted) return;
      if (_isEditing) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Program saved')));
        context.go('/trainer/cards');
      }
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildForm(List<WorkoutCard> cards, List<HabitTemplate> templates) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_isEditing ? 'Edit program' : 'New program', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. 6-Week Strength Foundations',
              border: OutlineInputBorder(),
            ),
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
          TextFormField(
            controller: _priceController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price (₹, 0 = free)', border: OutlineInputBorder()),
            validator: (value) {
              final parsed = num.tryParse((value ?? '').trim());
              if (parsed == null || parsed < 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [for (final option in _billingOptions) ButtonSegment(value: option.value, label: Text(option.label))],
            selected: {_billingPeriod},
            onSelectionChanged: _saving ? null : (selection) => setState(() => _billingPeriod = selection.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _workoutCardId,
            decoration: const InputDecoration(labelText: 'Workout card (optional)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(child: Text('None')),
              for (final card in cards) DropdownMenuItem<String?>(value: card.id, child: Text(card.title)),
            ],
            onChanged: _saving ? null : (value) => setState(() => _workoutCardId = value),
          ),
          const SizedBox(height: 16),
          const Text('Habits bundled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (templates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No habit templates yet -- build one from the Build tab first.',
                style: TextStyle(color: AppColors.inkSoftLight),
              ),
            )
          else
            for (final template in templates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(template.title),
                value: _selectedHabitTemplateIds.contains(template.id),
                onChanged: _saving
                    ? null
                    : (checked) => setState(() {
                        if (checked ?? false) {
                          _selectedHabitTemplateIds.add(template.id);
                        } else {
                          _selectedHabitTemplateIds.remove(template.id);
                        }
                      }),
              ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Published'),
            subtitle: const Text('Draft programs are only visible to you'),
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
    final cardsAsync = ref.watch(trainerCardsProvider);
    final templatesAsync = ref.watch(trainerHabitTemplatesProvider);

    Widget content(List<WorkoutCard> cards, List<HabitTemplate> templates) {
      if (!_isEditing) {
        return _buildForm(cards, templates);
      }
      final programAsync = ref.watch(programWithHabitsProvider(widget.programId!));
      return programAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load this program: $error')),
        data: (program) {
          _initFrom(program);
          return _buildForm(cards, templates);
        },
      );
    }

    final body = cardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load your cards: $error')),
      data: (cards) => templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your habit templates: $error')),
        data: (templates) => content(cards, templates),
      ),
    );

    if (!_isEditing) {
      if (widget.embedded) return body;
      return Scaffold(appBar: AppBar(title: const Text('Build')), body: body);
    }

    return Scaffold(appBar: AppBar(title: const Text('Edit program')), body: body);
  }
}
