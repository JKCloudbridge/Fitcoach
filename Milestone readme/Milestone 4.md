# Milestone 4 — Progress & habits

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`) without a live Supabase
project. It needs the manual steps in `Milestone 4 manual steps.md` — including
applying migrations 014-016 — before it runs end-to-end. Also assumes Milestone
3's own manual steps (migrations 010-013, `workout-api` redeployed) are already
done; as of this session they are **not** (last confirmed: only migration 006 is
live), so this milestone's own migrations 014-016 will need 007-013 applied ahead
of them (014-016 don't reference 007-013's tables directly, but habits' trainer-read
policy references `coaching_relationships`, which is 005 — apply everything in
order regardless).

## 0. Scope decisions made this session (asked, not assumed)

Three things were confirmed with the user before any code was written, per the
genuine gaps flagged going in — the concept HTML has no habit-tracking screen
at all (its client screens are only today/discover/progress/coach/profile), and
there's no trainer-side habit-template-builder screen either:

1. **Where habit tracking lives in the UI**: both — a daily check-off list on
   Today (`habits/presentation/today_habits_section.dart`), full streak history
   on Progress (`progress/presentation/progress_screen.dart`'s habits section).
2. **Trainer-authored `habit_templates` + a template-builder screen**: deferred
   to Milestone 4.5. This milestone's UI only reaches the self-created path
   (`template_id = null`, `source = 'self_created'`) — `habit_templates`' schema
   still ships now (see migration 014's header) so `habits.template_id` has
   something to reference, but nothing in the app writes to it yet.
3. **Migration status**: confirmed still only 006 live — 007-013 (Milestone 2/3's
   own migrations) have not been applied yet either. Flagged in the manual steps
   doc; nothing in this milestone's own code assumed otherwise.

## 1. What Was Built

**Schema** (`migrations/014-016`) — per `Initial requirement/Requirement 1` §9:

- `014_create_habit_templates.sql` — trainer-authored, mirrors `workout_cards`'
  visibility/moderation shape exactly (same RLS/grant shape as migration 006).
  Schema-ready, not yet reachable from the app — see decision 2 above.
- `015_create_habits.sql` — the per-client instance. Direct-RLS insert/update
  (no Edge Function), but the RLS `with check` only opens the door to exactly
  the self-created shape this milestone builds for: `client_id = auth.uid()`,
  `source = 'self_created'`, `template_id`/`trainer_id` both null, `type <>
  'wearable_auto'`. A future Milestone 4.5 `habits-api` route creating
  `trainer_assigned` rows will use the service-role connection, which bypasses
  RLS, so it doesn't need a matching policy branch here.
  `current_streak`/`best_streak` are **not** in `authenticated`'s grant column
  list at all (first use of column-level grants in this project) — only the
  streak trigger (below), running as the table owner, can write them. This is
  the actual enforcement of the doc's "maintained by update-habit-streaks... not
  computed per-request" — RLS governs which rows a client can touch, not which
  columns, so column-level grants were the right tool here, not an RLS trick.
- `016_create_habit_logs.sql` — unique `(habit_id, log_date)`, a real DB
  constraint this time (unlike `workout_logs`, which deliberately left
  "one log per exercise per day" as an app-level convention — `habit_id` is
  stable for a habit's lifetime, `assignment_exercise_id` isn't across
  re-assignments, so the doc's own unique constraint is exactly right here).
  Direct-RLS client writes locked to `source = 'manual'`. Also carries the
  streak-maintenance trigger:

  **Streak computation — a decision, not an oversight.** §9.2 says
  `current_streak`/`best_streak` are "maintained by update-habit-streaks Edge
  Function, not computed per-request", and Plan.md sketches that as a scheduled
  Supabase Cron job hitting a `habits-api` route. Built instead as a synchronous
  `AFTER INSERT OR UPDATE OR DELETE` trigger on `habit_logs` that recomputes both
  columns via a full rescan of that habit's logs — same call Milestone 3 made
  for `card_stats.follow_count` (migration 013's own comment: "a whole extra
  scheduled/Edge Function path for a one-line counter bump would be
  over-building it"). `habit_logs` rows are small per habit (one per day), so a
  full rescan on every write is cheap; no Cron wiring, no separate Edge
  Function, no scheduling to test against a live project this milestone.
  Revisit only if wearable_auto logging volume (Milestone 5) makes the
  per-row rescan cost actually matter.

**Backend** (`fitcoach_backend/`) — **no changes**. Per the scope decisions
above, self-created habit tracking needs no snapshot-at-creation transactional
logic (there's no template to snapshot from) and streak maintenance is now a DB
trigger, not an Edge Function — so there's nothing for a `habits-api` function
to do yet. Plan.md lists `habits-api` in its function table; standing it up as
an empty scaffold now would be building ahead of need, same "deferred until
actually needed" precedent as `moderation-api`. It's built in Milestone 4.5,
alongside the trainer-assigned/template-snapshot logic that actually needs it.

**Flutter app**:

- `pubspec.yaml` — added `fl_chart: ^1.2.0` (verified live against pub.dev this
  session: 1.2.0 current, SDK constraint `>=3.6.2 <4.0.0`, compatible with this
  project's `^3.12.2` pin). Genuinely new ground for the project — no
  sibling-app precedent, per Plan.md's own note, so no cross-app comparison was
  attempted.
- `lib/features/habits/` (new):
  - `data/habit_models.dart` — `Habit`, `HabitLog`, hand-written `fromMap`.
  - `data/habits_repository.dart` — direct-Supabase `fetchActiveHabits`,
    `fetchTodayLogs`, `createHabit` (self-created only), `logHabitToday` (an
    **upsert** on `(habit_id, log_date)`, unlike `workout_logs_repository`'s
    fetch-then-insert-or-update — habit_logs' real unique constraint makes the
    upsert safe and simpler).
  - `utils/merge_habits_with_logs.dart` — pure function, unit-tested, same
    convention as `assignments/utils/merge_exercises_with_logs.dart`.
  - `presentation/habits_providers.dart` — `activeHabitsProvider`,
    `todayHabitLogsProvider`.
  - `presentation/today_habits_section.dart` — the daily check-off list,
    embedded into `TodaySessionScreen` below the workout exercises. Renders
    nothing when the client has no habits yet (creation lives on Progress, not
    here). Binary habits toggle on tap; quantity habits open a small numeric
    dialog, `completed` derived from `value >= target_value` when a target
    exists.
  - `presentation/create_habit_sheet.dart` — the "+ Add a habit" bottom sheet
    (title, binary/quantity segmented control, unit + target for quantity),
    same `ConsumerStatefulWidget` sheet pattern as `LogSetSheet`.
- `lib/features/progress/` (new) — replaces `/client/progress`'s
  `ComingSoonScreen`:
  - `data/progress_models.dart` — `WeightLogEntry` (a `workout_logs` row joined
    with its exercise name).
  - `data/progress_repository.dart` — direct-Supabase reads only:
    `fetchLogsSince` (weekly adherence) and `fetchWeightLogs` (personal
    records) — both against Milestone 2's existing `workout_logs`/
    `assignment_exercises`, no new schema, per the doc's own scope note.
  - `utils/compute_weekly_adherence.dart` — pure function: Monday-Sunday
    adherence fractions from distinct `assignment_exercise_id`s logged per day
    over the active assignment's total exercise count. Unit-tested.
  - `utils/find_personal_record.dart` — pure function: the most-recently-set
    PR across every exercise the client has logged a weight for (max
    `actual_weight_kg` per exercise name; among those maxes, whichever was
    logged most recently), with a delta against that exercise's next-highest
    weight if one exists. Unit-tested, including a documented simplification
    (the delta compares against the second-highest weight *ever logged*, not
    necessarily the weight logged immediately before the PR).
  - `presentation/progress_providers.dart` — `weeklyAdherenceProvider`,
    `personalRecordProvider`.
  - `presentation/progress_screen.dart` — PR card, `fl_chart` `BarChart` for
    weekly adherence (Mon-Sun, matching the concept's own bar layout), and a
    habits section (streak + best-streak per active habit, "+ Add a habit"
    button opening `create_habit_sheet.dart`). Deliberately omits the concept's
    steps/resting-HR/sleep stat row — that's `wearable_metrics`, Milestone 5,
    same precedent `TodaySessionScreen` set in Milestone 2 for not faking
    unwired data.
- `lib/features/assignments/presentation/today_session_screen.dart` —
  restructured so the habits check-off section renders regardless of whether
  there's an active workout assignment (habits are tracked independently of a
  workout plan); pull-to-refresh now also invalidates the habit providers.
- `lib/core/router/app_router.dart` — `/client/progress`'s `ComingSoonScreen`
  is now `ProgressScreen`, same route path.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 55 tests passing (17 new: `Habit`/`HabitLog.fromMap`,
      `mergeHabitsWithLogs`, `WeightLogEntry.fromMap`,
      `computeWeeklyAdherence`, `findMostRecentPersonalRecord`, plus
      Milestones 0-3's existing 38)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/` (no
      changes this milestone)
- [x] `habit_templates` schema, RLS, Data API grants (schema-ready, unused by
      the app this milestone — see decision 2)
- [x] `habits` schema, RLS (client-owned direct-RLS insert/update scoped to
      the self-created shape; trainer read-only via active
      `coaching_relationships`), Data API grants including the new
      column-level insert/update grants that keep `current_streak`/
      `best_streak` client-unwritable
- [x] `habit_logs` schema, unique `(habit_id, log_date)`, RLS, Data API
      grants, and the streak-recompute trigger
- [x] Streak computation decision made and documented (synchronous DB
      trigger, not a scheduled Edge Function) — see §1 above
- [x] Client Today screen — habit check-off section (binary toggle, quantity
      value dialog), independent of whether a workout plan exists
- [x] Client Progress screen — PR card, `fl_chart` weekly adherence bars,
      habits section with streaks and habit creation
- [x] `fl_chart` added to `pubspec.yaml`, version verified live against
      pub.dev before pinning
- [ ] Migrations 014-016 applied to a live Supabase project — **you** need to
      do this first (see manual steps doc), after 005-013 are applied (015's
      trainer-read policy reads `coaching_relationships`, migration 005)
- [ ] A live device/emulator run of the full loop (client creates a habit on
      Progress → it shows up on Today → checking it off updates the streak on
      Progress → weekly adherence bars reflect real `workout_logs` data → a
      new heaviest set shows up as a personal record) — not yet run, no live
      project exists yet

## 3. Known Gaps / Deliberate Non-Scope

- **No habit-tracking UI in the concept mockup at all**, and no trainer-side
  template-builder screen either — both genuine additions built without a
  mockup reference this milestone, per the decisions in §0. Flagged going in,
  confirmed with the user before writing any UI code, same spirit as
  Milestone 3's "no start button in the mockup" gap.
- **Trainer-authored `habit_templates` + the assign flow are fully deferred to
  Milestone 4.5.** The schema/RLS/grants exist now; the builder screen,
  `habits-api` Edge Function, and the snapshot-at-creation transactional logic
  (habits' `trainer_assigned` path) do not. A client can only self-create
  habits this milestone.
- **`habits-api` doesn't exist yet.** Plan.md lists it in the backend function
  table, but nothing in this milestone's scope needs it (see §1's "Backend"
  note) — deferred to Milestone 4.5 alongside the trainer-authoring flow that
  actually requires it.
- **Wearable auto-completion (§9.4) is out of scope**, per the milestone's own
  instructions — `habit_logs.source`/`habits.type`/`habit_templates.type` all
  include `wearable_auto` in their schema (schema-ready, same precedent as
  `workout_cards.moderation_status`), but direct-RLS client writes are locked
  to `source = 'manual'` / `type <> 'wearable_auto'`, and nothing calls
  `sync-wearable-data`. Deferred to Milestone 5, not forgotten.
- **No archive/delete UI for a habit.** The schema supports `status =
  'archived'` and the RLS/grants allow a client to update their own habit's
  `status`, but no button calls it this milestone — not asked for, and adding
  one speculatively would be building ahead of need.
- **Personal-record delta is a documented simplification.** `deltaKg` compares
  the PR against that exercise's second-highest logged weight ever, not
  necessarily the weight logged immediately before the PR chronologically —
  see `find_personal_record.dart`'s own doc comment and its unit test.
- **Weekly adherence uses the *current* active assignment's exercise count as
  a constant denominator across the whole displayed week.** If a client's
  active assignment changed mid-week (a new plan assigned partway through),
  earlier days in the week are still divided by the *current* plan's exercise
  count, not whatever was active on that earlier day — inherits the same
  "single most-recently-assigned active plan" simplification
  `AssignmentsRepository`/`TodaySessionScreen` already carry from Milestone 2.
- **The habit streak trigger does a full rescan of a habit's logs on every
  write**, not an incremental update. Cheap at expected volumes (one log per
  habit per day); flagged in migration 016's own comment as the thing to
  revisit if Milestone 5's wearable-driven logging changes that math.
- Wearables, messaging, seats, the marketplace, full moderation tooling, and
  trainer-client-dashboard remain entirely out of scope, per this milestone's
  own instructions.
