# Milestone 4.5 — Trainer-authored habits

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`) without a live Supabase
project. It needs the manual steps in `Milestone 4.5 manual steps.md` — including
applying migrations 014-017 (014-016 carried over from Milestone 4, still not applied
to any live project either) and deploying the new `habits-api` function.

Closes out the two things Milestone 4 deliberately deferred: trainer-authored
`habit_templates` with a builder screen, and the trainer→client assign flow. Built
directly on top of Milestone 4's code, same branch, not yet committed separately.

## 0. Scope decisions made this session

Three questions asked before writing any code:

1. **Where does the trainer's template builder live?** Folded into the existing
   "My Cards"/"Build" tabs via a segmented toggle (Workout Cards / Habits),
   rather than a new bottom-nav destination — keeps the trainer shell's 5-tab
   shape Plan.md and the concept HTML both describe.
2. **What does `habits-api` need to build?** Reframed mid-session: the user's
   own framing — "habit tracking is something the client can track for their
   own betterment" — led to a materially smaller backend than first scoped.
   A habit has no child snapshot table (no `assignment_exercises` equivalent),
   so a client adopting a *public* template is just a direct-RLS insert
   copying the template's fields, same as self-created habits already work —
   **no Edge Function needed for that path at all.** Only the actual
   cross-user case — a trainer pushing one of their own templates to a
   specific client — needs `habits-api`, mirroring `assign-workout-card`
   exactly. This is a materially smaller backend than Milestone 4's own
   scoping conversation first assumed.
3. **Branch**: continued directly on `M4` (not yet pushed), to be committed
   together with Milestone 4's own work.

## 1. What Was Built

**Schema**:

- `014_create_habit_templates.sql` — **unchanged from Milestone 4**, now
  actually reachable from the app.
- `015_create_habits.sql` — **edited in place** (safe: never applied live,
  never committed). `habits_insert`'s RLS now allows `template_id` to be
  non-null while `source` stays `'self_created'` — a client adopting a public
  template — gated by an `exists` check that the template is genuinely
  `visibility = 'public'`, `is_published = true`, `moderation_status =
  'approved'`. Doesn't re-validate that every copied field matches the
  template exactly (a client tuning their own target on adoption is a
  legitimate use, not a hole); `template_id` isn't in the `update` column
  grant, so it can't be changed after the fact either way.
- `017_assign_habit_template_function.sql` (new) — `assign_habit_template()`,
  the trainer-push path. Same "validate everything, then insert" shape as
  migration 009's `assign_workout_card()`: confirms the template belongs to
  the calling trainer, confirms an active `coaching_relationships` row exists
  with the target client, then inserts a `trainer_assigned` habits row
  copying the template's fields in the same statement. No second insert into
  a child table, unlike `assign_workout_card()` — habits has nothing
  equivalent to `assignment_exercises`, the row itself is the snapshot.
  `security definer`, revoked from `public`/`anon`/`authenticated` — only
  reachable through `habits-api`'s service-role connection.

**Backend** (`fitcoach_backend/supabase/functions/habits-api/`, new) — one
route, `POST /habits-api/assign-habit-template`, `requireRole('trainer')`,
mirroring `workout-api/index.ts`'s `assign-workout-card` route file-for-file
(same zod schema shape, same `mapRpcError` error-code table pattern reusing
`_shared/auth.ts`/`_shared/errors.ts`/`_shared/supabaseAdmin.ts` unchanged).

**Flutter app — trainer side**, new `lib/features/habit_templates/`:

- `data/habit_template_models.dart` — `HabitTemplate`, mirrors `WorkoutCard`'s
  shape.
- `data/habit_templates_repository.dart` — direct-RLS CRUD (`fetchTrainer
  Templates`, `fetchTemplate`, `createTemplate`, `updateTemplate`), mirrors
  `WorkoutCardsRepository`.
- `data/assign_habit_template_repository.dart` — the one Dio call, mirrors
  `assign_workout_card_repository.dart`.
- `presentation/habit_templates_list_screen.dart` — mirrors `CardsListScreen`.
- `presentation/build_habit_template_screen.dart` — mirrors
  `BuildSessionScreen`, minus the exercises sub-list (a habit template has no
  child rows to manage — title/description/type/unit/default target/
  visibility/published is the whole form). `type` only offers Yes/No and
  Quantity in this builder — `wearable_auto` stays schema-ready but unexposed
  here (Milestone 5 is what would ever complete one).
- `presentation/assign_habit_template_sheet.dart` — mirrors
  `assign_card_sheet.dart` minus the date pickers (habits has no start/due
  date columns), reuses the existing `trainerActiveClientsProvider`.
- `presentation/trainer_library_screen.dart` / `trainer_build_screen.dart` —
  the fold-in wrappers: a `SegmentedButton` toggling between the existing
  workout-card screen and the new habit-template one. `CardsListScreen` and
  `BuildSessionScreen` (create-mode only) each got a small additive
  `embedded` constructor flag (default `false`, existing standalone routes
  unaffected) so they can render without their own nested `Scaffold`/`AppBar`
  when hosted inside these wrappers — avoids stacking two app bars without
  duplicating either screen's list/form logic.

**Flutter app — client side**:

- `habits/data/habits_repository.dart` — added `fetchPublicTemplates()` and
  `adoptTemplate()`. Same repository that already owns `createHabit`/
  `logHabitToday`, since adopting a public template is still "the client
  acting for themselves," same as Milestone 4's self-created path — this
  mirrors how `DiscoverRepository` (client-side) already reads
  `workout_cards` independently of `WorkoutCardsRepository` (trainer-side
  CRUD on the same table).
- `habits/presentation/create_habit_sheet.dart` — now a two-mode sheet
  (`SegmentedButton`: "From scratch" / "Browse templates"). The existing
  from-scratch form moved into `_ScratchHabitForm` unchanged; a new
  `_TemplateBrowser` lists public templates with an "Add" button that adopts
  one directly, no separate screen or route.

**Router** (`app_router.dart`) — `/trainer/cards` now builds
`TrainerLibraryScreen`; `/trainer/build` now builds `TrainerBuildScreen`; a
new nested route `/trainer/cards/templates/:templateId` builds
`BuildHabitTemplateScreen` for editing (sibling to the existing `:cardId`
route — GoRouter matches the literal `templates` segment before the dynamic
one, so there's no ambiguity).

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 57 tests passing (2 new: `HabitTemplate.fromMap`,
      plus Milestone 4's 55)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/`,
      including the new `habits-api`
- [x] `habit_templates` reachable end-to-end from the trainer side (create,
      edit, publish)
- [x] `habits` RLS loosened for client-adopts-public-template, still gated to
      genuinely public/published/approved templates
- [x] `assign_habit_template()` RPC + `habits-api` route for the
      trainer-push case
- [x] Trainer "My Cards"/"Build" tabs toggle between workout cards and habit
      templates, no new bottom-nav destination
- [x] Client "+ Add a habit" sheet offers both from-scratch and
      browse-and-adopt-a-public-template paths
- [ ] Migrations 014-017 applied to a live Supabase project — **you** need
      to do this (see manual steps doc); 014-016 were already outstanding
      from Milestone 4
- [ ] `habits-api` deployed — **you** need to do this (see manual steps doc)
- [ ] A live device/emulator run of both new loops (trainer builds a
      template → publishes it → a client sees and adopts it from "Browse
      templates"; trainer builds a private template → assigns it directly to
      a specific client → it shows up on that client's Today/Progress) — not
      yet run, no live project exists yet

## 3. Known Gaps / Deliberate Non-Scope

- **No mockup reference for any of this screen's UI** — the trainer
  template-builder form, the toggle wrappers, and the "Browse templates" tab
  are all built to match the app's own existing conventions
  (`BuildSessionScreen`, `AssignCardSheet`, `DiscoverScreen`'s bookmark-style
  row actions), not the concept HTML, since it has nothing to reference here
  — same gap flagged in Milestone 4.md, now addressed rather than deferred
  further.
- **No edit/delete/unadopt affordance for a client's adopted habit beyond
  what Milestone 4 already built** (archive-via-status-update exists at the
  schema/RLS level, no UI button calls it — see Milestone 4.md's own known
  gaps, unchanged here).
- **`_TemplateBrowser` doesn't filter or search public templates** — it's a
  flat list, same "don't over-build" call Milestone 3 made for Discover's
  own filter chips being the only filtering UI; a habit-template-specific
  Discover surface (search, tags, saved templates) wasn't asked for and
  would be building ahead of need at today's expected template volume.
- **A trainer assigning the same template to the same client twice creates
  two separate `habits` rows** — `assign_habit_template()` has no duplicate
  guard, unlike `follow_public_card()`'s `ALREADY_FOLLOWING` check. Not
  addressed this milestone; flagged as a gap to close if it turns out to
  matter in practice, not a correctness risk (each row just tracks
  independently).
- **Wearable-typed templates remain unbuildable from the UI** —
  `build_habit_template_screen.dart` only offers Yes/No and Quantity, per
  §0's decision 2 area — `wearable_auto` stays schema-ready, not exposed,
  same precedent as Milestone 4's own `habit_logs.source`.
- Wearables, messaging, seats, the marketplace, full moderation tooling, and
  trainer-client-dashboard remain entirely out of scope, per Milestone 4's
  own instructions (unchanged by this milestone).
