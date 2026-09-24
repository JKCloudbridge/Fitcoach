import 'package:flutter/material.dart';

import '../../programs/presentation/build_program_screen.dart';
import '../../workout_cards/presentation/build_session_screen.dart';
import 'build_habit_template_screen.dart';

const _buildOptions = [
  (value: 'card', label: 'Workout Card'),
  (value: 'habit', label: 'Habit Template'),
  (value: 'program', label: 'Program'),
];

/// The trainer's "Build" tab, now toggling between building a new
/// workout_cards row, a new habit_templates row, and (Milestone 8) a new
/// programs row -- same fold-in as TrainerLibraryScreen. Only covers the
/// *create* case; editing an existing card/template/program is reached
/// through its own pushed route (`/trainer/cards/:cardId`,
/// `/trainer/cards/templates/:templateId`, `/trainer/cards/programs/:programId`),
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
      body: switch (_mode) {
        'card' => const BuildSessionScreen(embedded: true),
        'habit' => const BuildHabitTemplateScreen(embedded: true),
        _ => const BuildProgramScreen(embedded: true),
      },
    );
  }
}
