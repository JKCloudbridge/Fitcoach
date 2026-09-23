import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A static, non-interactive tag -- `.goal-tags span` in the concept CSS
/// (solid stone background, ink text, no border). Distinct from the
/// bordered/toggleable `.chip` pattern the global `ChipThemeData` covers --
/// this is for plain display (profile certifications/goals), not selection.
class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stoneDark : AppColors.stoneLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.inkOnDark : AppColors.ink)),
    );
  }
}
