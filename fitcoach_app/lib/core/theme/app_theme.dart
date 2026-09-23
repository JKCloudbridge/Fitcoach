import 'package:flutter/material.dart';

/// Placeholder Material 3 theme for Milestone 0 -- real brand colors/type
/// scale come from the UI concept (Initial requirement/fitcoach-ui-concept.html)
/// once a design pass happens; this just gets the app running.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
  );
}
