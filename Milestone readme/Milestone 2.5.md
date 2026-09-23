# Milestone 1.5 — Design pass

Status: **code complete.** A design pass on Milestones 0-2's screens, not new
functionality — `app_theme.dart`'s own comment flagged the Material 3 seed-color
placeholder as pending "a design pass" since Milestone 0; this milestone replaces
it with a real `AppTheme` built from `Initial requirement/fitcoach-ui-concept.html`'s
actual design tokens, before Milestone 2 could add more screens on top of the wrong
look (Milestone 2's screens were already built by the time this pass started, so
they're retrofitted here too, per this milestone's own scope note).

## 1. What Changed

**`fitcoach_app/lib/core/theme/app_theme.dart`** — rewritten from a single
`ColorScheme.fromSeed(seedColor: Color(0xFF2E7D32))` placeholder into a real
`AppTheme.light`/`AppTheme.dark`, built directly from the concept HTML's CSS custom
properties (`:root` block + its `prefers-color-scheme: dark` override), not from
either sibling app — neither has this brand's palette:

- `AppColors` — `ink` (#16241F), `lime` (#B7DB4B), `coral` (#E75539) constant across
  light/dark, matching the concept CSS exactly (only `paper`/`stone`/`card`/
  `ink-soft` get dark-mode overrides there). Light: `paper` #F6F4EE, `stone` #E8E3D3,
  `card` #FFFFFF, `ink-soft` #55665C. Dark: `paper` #10231C, `stone` #1B342A, `card`
  #17281F, `ink-soft` #9FB3A6.
- Type: `GoogleFonts.barlowCondensedTextTheme()` for `headlineLarge/Medium/Small`
  and `titleLarge/Medium` (the concept's `.display` class — hero/screen titles,
  stat numbers, PR values), `GoogleFonts.interTextTheme()` for everything else
  (body text, buttons, labels) — no bundled font assets, matches the already-pinned
  `google_fonts` package, same two-font structural split Proximity's own
  `app_theme.dart` uses for its two brand faces (referenced for file organization
  only — the colors/type come from the concept, not from Proximity).
- Component themes so this propagates automatically: `NavigationBarThemeData`
  (dark ink tab bar, lime active icon/label, `#7C8C82` inactive, no Material
  indicator pill — matches `.tabbar`), `FilledButtonThemeData` (`.cta` — solid
  lime pill, 14px radius, no shadow) + `OutlinedButtonThemeData` (`.cta.ghost` —
  transparent, stone border), `CardThemeData` (`.exercise-card`-style — card
  surface, stone border, 16px radius, no shadow), `ChipThemeData` (`.chip`/
  `.chip.on` — bordered pill default, solid ink+paper when selected),
  `SwitchThemeData` (`.switch`/`.switch.on`), `SegmentedButtonThemeData`
  (`.segmented`/`.seg.on`), `InputDecorationTheme` (`.field input.fval`),
  `AppBarTheme`, `DividerThemeData`, `ProgressIndicatorThemeData`.
- `main.dart` — wired `darkTheme: AppTheme.dark` and `themeMode: ThemeMode.system`
  alongside the existing `theme: AppTheme.light`.

**A genuine gap in the concept's own dark-mode CSS, and the judgment call made
here**: the `prefers-color-scheme: dark` override block redefines `--paper`,
`--stone`, `--card`, and `--ink-soft`, but never `--ink` itself. Taken literally,
`body { color: var(--ink) }` would render `#16241F` text on the new `#10231C`
background in dark mode — both are near-black, so that's unreadable, not an
intentional "ink stays dark" choice. Since `--ink-soft` *does* get a lighter
dark-mode value, primary text needs an equivalent one too. `AppColors.inkOnDark`
reuses light mode's `paper` (#F6F4EE) for this, keeping it in the same palette
family rather than introducing a generic white. **Flagged here for design
review** — if the concept's author intended something else for dark-mode text,
this is the one place this milestone deviated from the literal token set.

**`fitcoach_app/lib/shared/widgets/tag_pill.dart`** — new. Matches `.goal-tags
span` (solid stone background, ink text, no border) — a distinct concept pattern
from the bordered/toggleable `.chip`, which the global `ChipThemeData` covers
instead. Used in place of the plain Material `Chip` widget for:

- `features/profile/presentation/trainer_profile_screen.dart` — certifications
  tags, "Verified" badge
- `features/profile/presentation/client_profile_screen.dart` — goals tags

**`features/onboarding/presentation/role_select_screen.dart`** — `_RoleCard`'s
selection state rewritten from generic `ColorScheme.primary`/`primaryContainer`
tinting to the concept's actual language: a `.exercise-card`-style container
(card surface, stone border, 16px radius) that switches to a lime border + a
small solid-lime check circle when selected — the same "lime = the chosen/active
one" convention the concept uses for `.dot-check.done`, the active tab, and
`.switch.on`. Role-select isn't one of the concept's phone mockups, so this is
built from its established visual language rather than copied from a screen that
doesn't exist.

**Error text and button spinners, across 7 screens** (`login_screen.dart`,
`email_otp_screen.dart`, `role_select_screen.dart`, both profile edit screens,
`assign_card_sheet.dart`, `build_session_screen.dart`, `log_set_sheet.dart`) —
`Text(color: Colors.red)` → `Text(color: AppColors.coral)` (the concept's
warning/destructive color, `.badge.warn`/`.stat-box.warm`), and the loading
spinner inside every `FilledButton` → `Colors.white` → `AppColors.ink`, since
`FilledButton`'s background is now the light `lime` color, not a dark Material
primary — a white spinner on lime had weak contrast and didn't match the
button's own ink-colored label.

**Everything else** — login/OTP/profile-view/profile-edit screens and both
shells' bottom nav needed no direct code changes; they pick up `AppTheme`'s
`colorScheme`/`textTheme`/component themes automatically, per Flutter's
`Text`/`TextStyle.inherit` merging with the ambient `DefaultTextStyle` (verified
live, not assumed — see §2).

## 2. Verification

- `flutter analyze` — no issues
- `flutter test` — 33 tests passing (unchanged from Milestone 2 — this was a
  visual-only pass, no logic changed)
- **Live device run**: built and ran on a physical Android device (motorola edge
  70, Android 17) via `flutter run`. Screenshotted the login screen — confirmed
  live: paper background, lime `FilledButton` CTA with ink text and no shadow,
  stone-bordered `OutlinedButton` and `TextField`, coral error text rendering
  correctly (the error shown, `AuthRetryableFetchException`/failed host lookup,
  is expected — `.env` still has placeholder Supabase credentials per Milestone
  0/1's own outstanding manual steps, not a theme bug).
- **Login/auth screens aren't in the concept HTML** (no phone-frame mockup
  exists for them) — per this milestone's own instructions, built to stay
  consistent with the rest of the palette/type rather than compared pixel-for-
  pixel against a mockup that doesn't exist.
- **What could not be visually verified live, and why**:
  - Role-select, both profile view screens, and both profile edit screens all
    require a real signed-in session (Milestone 1's own manual steps —
    real Google OAuth credentials and a working Email OTP template — are still
    outstanding, confirmed live by the screenshot above). Reviewed by reading
    the theme's cascading effect on each screen's widget tree instead;
    not screenshotted.
  - Milestone 2's screens (`CardsListScreen`, `BuildSessionScreen`,
    `TodaySessionScreen`, the assign/log-set sheets) are behind the same auth
    wall, plus need migrations 006-009 and a `coaching_relationships` test row
    applied to a live project (Milestone 2's own manual steps, also still
    outstanding as of this pass).
  - Dark mode (`AppTheme.dark`) was reviewed in code only — not visually
    verified live (would need the device's system dark mode toggled and the
    app relaunched; not done this pass).
  - Discover, Progress, Coach/Messages, and other still-`ComingSoonScreen` tabs
    were not touched — out of scope, matching Milestone 1's own instructions
    that only `Today`/`My Cards`/`Build` (Milestone 2) and Profile (Milestone 1)
    are real screens so far.

## 3. Known Gaps / Deliberate Non-Scope

- The dark-mode `--ink` gap above — flagged for design review, not silently
  patched over.
- A handful of inline `TextStyle`s that set `fontSize`/`fontWeight` directly
  (e.g. login screen's "FitCoach" wordmark) don't reference `textTheme.headline*`
  explicitly, so they render in Inter (the ambient body font) rather than Barlow
  Condensed, even though they're brand-moment text a designer might want in the
  display face. Not rewritten here — the instructions scoped this pass to
  "screens pick up the new ThemeData for free" plus a few explicitly-named ad-hoc
  widgets (`_RoleCard`, profile Chips), not a line-by-line rewrite of every
  inline `TextStyle` in the app.
- No new reusable widgets were built for exercise rows, build-session drag
  handles, discover cards, stat boxes, PR cards, or segmented controls, per this
  milestone's own instructions — their component themes
  (`CardThemeData`/`SegmentedButtonThemeData`/etc.) exist now so Milestone 2+
  screens can use plain Material widgets and get the right look, but the actual
  screens/patterns themselves are still Milestone 2+'s job.
- Full live visual verification of every screen (not just login) still needs
  Milestones 0/1/2's own outstanding manual steps done first (real OAuth
  credentials, migrations 006-009 applied, a test `coaching_relationships` row)
  — this pass got as far as those milestones' own docs already allow.
