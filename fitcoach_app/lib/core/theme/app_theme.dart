import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FitCoach's design system -- lifted directly from the concept HTML's own
/// CSS custom properties (Initial requirement/fitcoach-ui-concept.html's
/// `:root` block and its `prefers-color-scheme: dark` override), not from
/// either sibling app -- neither has this brand's palette. `ink`, `lime`, and
/// `coral` stay constant across light/dark per the concept CSS; only
/// `paper`/`stone`/`card`/`inkSoft` get dark-mode overrides there.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF16241F);
  static const lime = Color(0xFFB7DB4B);
  static const coral = Color(0xFFE75539);

  static const paperLight = Color(0xFFF6F4EE);
  static const stoneLight = Color(0xFFE8E3D3);
  static const cardLight = Color(0xFFFFFFFF);
  static const inkSoftLight = Color(0xFF55665C);

  static const paperDark = Color(0xFF10231C);
  static const stoneDark = Color(0xFF1B342A);
  static const cardDark = Color(0xFF17281F);
  static const inkSoftDark = Color(0xFF9FB3A6);

  /// Not a token the concept CSS actually defines. Its dark-mode override
  /// block redefines --paper/--stone/--card/--ink-soft but never --ink
  /// itself, which would leave `body { color: var(--ink) }` rendering
  /// #16241F text on a #10231C background in dark mode -- both are
  /// near-black, so that's unreadable, not an intentional "ink stays dark"
  /// choice. Since --ink-soft *does* get a lighter dark-mode value, primary
  /// text needs an equivalent -- reusing light mode's paper keeps it in the
  /// same palette family rather than reaching for a generic white. Flagged
  /// in Milestone 1.5.md for design review.
  static const inkOnDark = paperLight;

  /// Tab bar / "always-dark" surfaces (`.tabbar`, `.pr-card`) use `ink`
  /// literally in both themes per the CSS, so text placed on them needs a
  /// light foreground in both themes too -- this is that color, not a
  /// dark-mode-only concern.
  static const onInk = paperLight;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    paper: AppColors.paperLight,
    stone: AppColors.stoneLight,
    card: AppColors.cardLight,
    inkSoft: AppColors.inkSoftLight,
    text: AppColors.ink,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    paper: AppColors.paperDark,
    stone: AppColors.stoneDark,
    card: AppColors.cardDark,
    inkSoft: AppColors.inkSoftDark,
    text: AppColors.inkOnDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color paper,
    required Color stone,
    required Color card,
    required Color inkSoft,
    required Color text,
  }) {
    // Barlow Condensed for numeric/display moments (`.display`, `.num`,
    // `.pval`), Inter for everything else -- same two-font structural split
    // Proximity's own app_theme.dart uses for its two brand faces, applied
    // here to this brand's actual fonts per the concept CSS.
    final displayFont = GoogleFonts.barlowCondensedTextTheme();
    final bodyFont = GoogleFonts.interTextTheme();

    final textTheme = bodyFont
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          headlineLarge: displayFont.headlineLarge?.copyWith(color: text, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          headlineMedium: displayFont.headlineMedium?.copyWith(color: text, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          headlineSmall: displayFont.headlineSmall?.copyWith(color: text, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          titleLarge: displayFont.titleLarge?.copyWith(color: text, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          titleMedium: displayFont.titleMedium?.copyWith(color: text, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.lime,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.lime,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.lime,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.ink,
      onSecondary: AppColors.onInk,
      surface: card,
      onSurface: text,
      surfaceContainerHighest: stone,
      onSurfaceVariant: inkSoft,
      outline: stone,
      outlineVariant: stone,
      error: AppColors.coral,
      onError: Colors.white,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.onInk,
    );

    final outlineSide = BorderSide(color: stone);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: textTheme,
      dividerColor: stone,
      dividerTheme: DividerThemeData(color: stone, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),

      // `.cta` -- solid lime pill, no shadow. `colorScheme.primary`/
      // `onPrimary` already carry lime/ink through, this just fixes shape,
      // padding, and elevation to match the concept instead of Material's
      // defaults.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.lime.withValues(alpha: 0.55),
          disabledForegroundColor: AppColors.ink.withValues(alpha: 0.55),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // `.cta.ghost` -- transparent bg, stone border, ink text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: outlineSide,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: text, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),

      iconTheme: IconThemeData(color: text),

      // `.exercise-card`/`.stat-box`/`.disc-card`-style container: card
      // surface, stone border, 16px radius, no shadow.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: outlineSide),
      ),

      // `.field input.fval` -- card surface, stone border, 12px radius.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: outlineSide),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: outlineSide),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.lime, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: inkSoft),
        hintStyle: TextStyle(color: inkSoft),
      ),

      // `.tabbar` -- always-dark ink background (both themes, per the CSS),
      // lime active icon/label, muted #7C8C82 inactive -- no Material
      // indicator pill, the concept only changes icon/label color.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.ink,
        indicatorColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.lime : const Color(0xFF7C8C82), size: 22),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.lime : const Color(0xFF7C8C82),
          ),
        ),
      ),

      // `.chip`/`.chip.on` -- bordered pill (paper/transparent bg, inkSoft
      // text) by default, solid ink bg + paper text when selected. Static
      // tag display (profile certifications/goals, `.goal-tags`) uses the
      // shared/widgets/tag_pill.dart widget instead of Chip -- a distinct
      // concept pattern (solid stone, no border), not this one.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: outlineSide,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: inkSoft, fontSize: 11.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        selectedColor: AppColors.ink,
        secondarySelectedColor: AppColors.ink,
        checkmarkColor: AppColors.onInk,
        secondaryLabelStyle: TextStyle(color: AppColors.onInk, fontSize: 11.5),
      ),

      // `.switch`/`.switch.on` -- stone track off, lime track on, white knob.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.lime : stone,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // `.segmented`/`.seg.on` -- selected segment gets the card surface +
      // bold ink text, unselected stays transparent + inkSoft.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? card : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? text : inkSoft,
          ),
          side: WidgetStatePropertyAll(outlineSide),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.lime),
    );
  }
}
