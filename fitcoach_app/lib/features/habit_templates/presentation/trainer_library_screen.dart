import 'package:flutter/material.dart';

import '../../workout_cards/presentation/cards_list_screen.dart';
import 'habit_templates_list_screen.dart';

const _libraryOptions = [
  (value: 'cards', label: 'Workout Cards'),
  (value: 'habits', label: 'Habits'),
];

/// The trainer's "My Cards" tab, now toggling between workout_cards and
/// habit_templates -- per the user's own answer when asked where the
/// trainer habit-template builder should live: folded into the existing
/// tabs via a toggle, rather than a new bottom-nav destination.
/// CardsListScreen itself is untouched; this just wraps it alongside its new
/// habit-template sibling.
class TrainerLibraryScreen extends StatefulWidget {
  const TrainerLibraryScreen({super.key});

  @override
  State<TrainerLibraryScreen> createState() => _TrainerLibraryScreenState();
}

class _TrainerLibraryScreenState extends State<TrainerLibraryScreen> {
  String _mode = 'cards';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cards'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: SegmentedButton<String>(
              segments: [for (final option in _libraryOptions) ButtonSegment(value: option.value, label: Text(option.label))],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() => _mode = selection.first),
            ),
          ),
        ),
      ),
      body: _mode == 'cards' ? const CardsListScreen(embedded: true) : const HabitTemplatesListScreen(),
    );
  }
}
