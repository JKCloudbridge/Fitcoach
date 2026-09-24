import 'package:flutter/material.dart';

import '../../workout_cards/presentation/build_session_screen.dart';
import 'build_habit_template_screen.dart';

const _buildOptions = [
  (value: 'card', label: 'Workout Card'),
  (value: 'habit', label: 'Habit Template'),
];

/// The trainer's "Build" tab, now toggling between building a new
/// workout_cards row and a new habit_templates row -- same fold-in as
/// TrainerLibraryScreen. Only covers the *create* case; editing an existing
/// card or template is reached through its own pushed route
/// (`/trainer/cards/:cardId` or `/trainer/cards/templates/:templateId`),
/// each with its own AppBar, unaffected by this toggle.
class TrainerBuildScreen extends StatefulWidget {
  const TrainerBuildScreen({super.key});

  @override
  State<TrainerBuildScreen> createState() => _TrainerBuildScreenState();
}

class _TrainerBuildScreenState extends State<TrainerBuildScreen> {
  String _mode = 'card';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: SegmentedButton<String>(
              segments: [for (final option in _buildOptions) ButtonSegment(value: option.value, label: Text(option.label))],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() => _mode = selection.first),
            ),
          ),
        ),
      ),
      body: _mode == 'card' ? const BuildSessionScreen(embedded: true) : const BuildHabitTemplateScreen(embedded: true),
    );
  }
}
