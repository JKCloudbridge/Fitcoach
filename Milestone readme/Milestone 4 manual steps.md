# Milestone 4 — Manual Steps Required From You

As of this session, **migrations 007-013 (Milestones 2 and 3) are still not
applied to the live project** — only 006 is confirmed live. Apply everything
below in full numeric order; don't skip straight to 014-016, since migration
015's trainer-read policy on `habits` reads `coaching_relationships`
(migration 005), and Milestone 3's own manual steps doc has the 007-013 steps
if you haven't run them yet.

## 1. Apply migrations 007-016 (in order)

```
cd fitcoach_backend
supabase db query -f "../migrations/007_create_workout_assignments_and_assignment_exercises.sql" --linked
supabase db query -f "../migrations/008_create_workout_logs.sql" --linked
supabase db query -f "../migrations/009_assign_workout_card_function.sql" --linked
supabase db query -f "../migrations/010_create_card_stats.sql" --linked
supabase db query -f "../migrations/011_create_saved_cards.sql" --linked
supabase db query -f "../migrations/012_create_card_reports.sql" --linked
supabase db query -f "../migrations/013_follow_public_card_function.sql" --linked
supabase db query -f "../migrations/014_create_habit_templates.sql" --linked
supabase db query -f "../migrations/015_create_habits.sql" --linked
supabase db query -f "../migrations/016_create_habit_logs.sql" --linked
```

If 007-013 are already applied (check first — e.g. `select * from
workout_assignments limit 1` shouldn't error), skip straight to 014-016. Run
014 before 015 (habits.template_id references habit_templates) and 015 before
016 (habit_logs.habit_id references habits, and 016's trigger updates habits).

No backfill needed for any of the three: `habit_templates`, `habits`, and
`habit_logs` are all brand new tables with 0 rows by definition.

## 2. No Edge Function deploy this milestone

Unlike Milestones 2-3, there's nothing to deploy here — this milestone's habit
tracking is entirely direct-RLS (see Milestone 4.md §1's "Backend" note for
why `habits-api` wasn't built). If `workout-api` still hasn't been redeployed
with Milestone 3's `follow-public-card` route, that's still outstanding from
Milestone 3's own manual steps, not this one.

## 3. Confirm `fitcoach_app/.env`

Nothing new was added to `.env`'s shape this milestone — no new Edge Function
means no new route to reach. No `build_runner` re-run needed.

## 4. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

`flutter pub get` will pull in `fl_chart` (already verified locally this
session — see step 6 below for what a live run would additionally confirm).

## 5. Create at least one habit and one active workout assignment to test against

- A client needs at least one active `workout_assignments` row (Milestone 2's
  manual steps — a trainer builds and assigns a card, or the client follows a
  public one per Milestone 3) for the weekly adherence chart to show anything
  other than its empty state.
- Habits are entirely self-serve from the app now — open the client Progress
  screen, tap "+ Add a habit", no separate setup needed.
- For the personal-record card to show anything, log at least one set with a
  weight via `LogSetSheet` (tap an exercise on Today, fill in "Weight (kg)").

## 6. What still needs a live project + the steps above to actually verify

- Migrations 014-016 actually applying cleanly against a real Postgres
  instance — the `habit_templates`/`habits`/`habit_logs` RLS policies, the
  column-level grants on `habits` (first use of that grant shape in this
  project), and the streak-recompute trigger are all untested against real
  data, only reviewed by hand and `deno check`/`flutter analyze`/`flutter
  test` so far.
- The column-level grants specifically: confirm a client's own Supabase
  session actually gets rejected (not just silently ignored) if something
  tries to `PATCH .../habits?id=eq.X` with `current_streak` in the body —
  reviewed by hand against Postgres' column-privilege behavior, not run
  against a live database yet.
- The full self-created-habit loop: Progress → "+ Add a habit" → it appears on
  both Progress and Today → checking it off on Today → `current_streak`
  increments on Progress after a refresh → checking it off again the next day
  (or manually inserting a `habit_logs` row for yesterday via SQL, to test
  without waiting a real day) → streak continues; missing a day → streak resets
  to 0 on the next log.
- Quantity-type habits specifically: create one with a target, log a value
  under target (should show as not completed) and a value at/over target
  (should show completed) — the `completed = value >= target_value` logic in
  `today_habits_section.dart` is untested against a live upsert.
- The weekly adherence chart against real `workout_logs` data — confirm the
  Monday-Sunday bars actually line up with the calendar week and that
  re-logging the same exercise twice in one day doesn't double-count (unit
  tests cover the pure function in isolation, not the live query + provider
  chain).
- The personal-record card against a client with multiple weighted exercises
  logged over time — confirm the right one surfaces as "most recent" and the
  delta looks sensible.
- Whether `habits`/`habit_logs`' trainer-read RLS (EXISTS against an active
  `coaching_relationships` row) is actually sufficient once a second
  trainer/client account starts probing it — same "reviewed by hand, not by a
  second account" caveat every prior milestone's manual steps have flagged.
