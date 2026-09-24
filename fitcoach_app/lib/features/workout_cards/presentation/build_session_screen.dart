import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/workout_card_models.dart';
import '../data/workout_cards_repository.dart';
import 'workout_cards_providers.dart';

const _visibilityOptions = [
  (value: 'private', label: 'Private'),
  (value: 'gym_only', label: 'Gym'),
  (value: 'public', label: 'Public'),
];

const _difficultyOptions = ['beginner', 'intermediate', 'advanced'];

/// A single exercise row's editable state -- plain TextEditingControllers,
/// same "no form_builder" convention as the rest of the app. `id` carries
/// over an existing exercise's id (unused by the save path today, since
/// replaceExercises does a full delete+insert, but kept for a future
/// finer-grained diff if this screen ever needs one).
class _ExerciseRow {
  _ExerciseRow({this.id, String name = '', String sets = '3', String reps = '', String weightKg = '', String restSeconds = '60', String notes = ''})
    : nameController = TextEditingController(text: name),
      setsController = TextEditingController(text: sets),
      repsController = TextEditingController(text: reps),
      weightController = TextEditingController(text: weightKg),
      restController = TextEditingController(text: restSeconds),
      notesController = TextEditingController(text: notes);

  final String? id;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final TextEditingController restController;
  final TextEditingController notesController;

  factory _ExerciseRow.fromExercise(Exercise exercise) => _ExerciseRow(
    id: exercise.id,
    name: exercise.name,
    sets: exercise.sets.toString(),
    reps: exercise.reps,
    weightKg: exercise.weightKg?.toString() ?? '',
    restSeconds: exercise.restSeconds.toString(),
    notes: exercise.notes ?? '',
  );

  Exercise toExercise(int orderIndex) => Exercise(
    id: id,
    name: nameController.text.trim(),
    orderIndex: orderIndex,
    sets: int.tryParse(setsController.text.trim()) ?? 1,
    reps: repsController.text.trim(),
    weightKg: num.tryParse(weightController.text.trim()),
    restSeconds: int.tryParse(restController.text.trim()) ?? 60,
    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
  );

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    restController.dispose();
    notesController.dispose();
  }
}

/// "Build the session" -- create (cardId == null) or edit (cardId != null) a
/// workout card + its exercises, per Requirement 1 §3.6-3.7 and the UI
/// concept's builder screen (its single free-text "3 × 10" set field is
/// illustrative UX only -- the real form uses the schema's separate
/// sets/reps/weight_kg/rest_seconds columns).
class BuildSessionScreen extends ConsumerStatefulWidget {
  const BuildSessionScreen({super.key, this.cardId, this.embedded = false});

  final String? cardId;

  /// True when a parent screen already provides the Scaffold + AppBar --
  /// only meaningful for the create case (cardId == null); Milestone 4.5's
  /// TrainerBuildScreen embeds this alongside BuildHabitTemplateScreen
  /// behind a toggle. Defaults to false so `/trainer/build`'s existing
  /// standalone behavior is unchanged.
  final bool embedded;

  @override
  ConsumerState<BuildSessionScreen> createState() => _BuildSessionScreenState();
}

class _BuildSessionScreenState extends ConsumerState<BuildSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _exercises = <_ExerciseRow>[];

  String _visibility = 'private';
  String _difficulty = 'beginner';
  bool _isPublished = false;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.cardId != null;

  void _initFrom(WorkoutCard card, List<Exercise> exercises) {
    if (_initialized) return;
    _titleController.text = card.title;
    _descriptionController.text = card.description ?? '';
    _visibility = card.visibility;
    _difficulty = card.difficulty;
    _isPublished = card.isPublished;
    _exercises.addAll(exercises.map(_ExerciseRow.fromExercise));
    _initialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final row in _exercises) {
      row.dispose();
    }
    super.dispose();
  }

  void _addExercise() => setState(() => _exercises.add(_ExerciseRow()));

  void _removeExercise(int index) => setState(() => _exercises.removeAt(index).dispose());

  void _moveExercise(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _exercises.length) return;
    setState(() {
      final row = _exercises.removeAt(index);
      _exercises.insert(target, row);
    });
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
      final repository = ref.read(workoutCardsRepositoryProvider);
      final cardId = widget.cardId ?? await repository.createCard(
        trainerId: trainerId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        visibility: _visibility,
        difficulty: _difficulty,
        isPublished: _isPublished,
      );
      if (_isEditing) {
        await repository.updateCard(
          cardId: cardId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: _visibility,
          difficulty: _difficulty,
          isPublished: _isPublished,
        );
      }
      await repository.replaceExercises(cardId, [for (var i = 0; i < _exercises.length; i++) _exercises[i].toExercise(i)]);

      ref.invalidate(trainerCardsProvider);
      if (widget.cardId != null) ref.invalidate(cardWithExercisesProvider(widget.cardId!));

      if (!mounted) return;
      if (_isEditing) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card saved')));
        context.go('/trainer/cards');
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
          Text(_isEditing ? 'Build the session' : 'New card', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Lower Body Strength — Week 3', border: OutlineInputBorder()),
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
            segments: [for (final option in _visibilityOptions) ButtonSegment(value: option.value, label: Text(option.label))],
            selected: {_visibility},
            onSelectionChanged: _saving ? null : (selection) => setState(() => _visibility = selection.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
            items: [for (final d in _difficultyOptions) DropdownMenuItem(value: d, child: Text(d))],
            onChanged: _saving ? null : (value) => setState(() => _difficulty = value ?? _difficulty),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Published'),
            subtitle: const Text('Draft cards are only visible to you'),
            value: _isPublished,
            onChanged: _saving ? null : (value) => setState(() => _isPublished = value),
          ),
          const SizedBox(height: 8),
          const Text('Exercises', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (var i = 0; i < _exercises.length; i++) _buildExerciseRow(i),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
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

  Widget _buildExerciseRow(int index) {
    final row = _exercises[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.nameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Exercise name', isDense: true),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                IconButton(icon: const Icon(Icons.arrow_upward), onPressed: _saving || index == 0 ? null : () => _moveExercise(index, -1)),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: _saving || index == _exercises.length - 1 ? null : () => _moveExercise(index, 1),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: _saving ? null : () => _removeExercise(index)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.setsController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.repsController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Reps', hintText: 'e.g. 8-10', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.weightController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.restController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rest (s)', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      if (widget.embedded) return _buildForm();
      return Scaffold(appBar: AppBar(title: const Text('Build')), body: _buildForm());
    }

    final cardAsync = ref.watch(cardWithExercisesProvider(widget.cardId!));
    return Scaffold(
      appBar: AppBar(title: const Text('Build the session')),
      body: cardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load this card: $error')),
        data: (result) {
          final (card, exercises) = result;
          _initFrom(card, exercises);
          return _buildForm();
        },
      ),
    );
  }
}
