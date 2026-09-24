# Milestone 4.5 — Manual Steps Required From You

Supersedes Milestone 4's own manual steps doc for the migration-order section —
follow this one instead if you haven't applied any of 014-017 yet. As of this
session, **nothing past migration 006 is confirmed live.**

## 1. Apply migrations 007-017 (in order)

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
supabase db query -f "../migrations/017_assign_habit_template_function.sql" --linked
```

If 007-013 are already applied, skip to 014. If 014-016 are already applied
from a Milestone 4 manual-steps run **before this session's edit to 015**,
you need to re-apply 015 specifically — its RLS changed (the client-adopts-
a-public-template case was added). `create policy` isn't idempotent, so:

```sql
drop policy if exists habits_insert on habits;
drop policy if exists habits_update on habits;
```

then re-run 015's `create policy habits_insert ...` / `create policy
habits_update ...` blocks (or just re-run the whole file — `create table`
will fail loudly if `habits` already exists, telling you it's already
applied past that point; the policy drops above are what you actually need).
If you haven't applied 014-016 at all yet, just run the full file in order
as listed above — nothing special needed.

## 2. Deploy the new `habits-api` Edge Function

```
cd fitcoach_backend
supabase functions deploy habits-api
```

First deploy of this function — no existing routes to preserve. No new
secrets needed (same auto-injected `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`
every other function uses).

## 3. Confirm `fitcoach_app/.env`

`EDGE_FUNCTIONS_BASE_URL` (set since Milestone 0) already covers
`habits-api` — it's the same root Functions URL every domain function shares.
No `.env` changes, no `build_runner` re-run needed.

## 4. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

## 5. Create a public and a private habit template to test against

- As a trainer: open the "Build" tab, toggle to "Habit Template", fill in a
  title, pick Yes/No or Quantity, set visibility to **Public** and
  **Published** on — this is what a client will see under "Browse templates".
- Build a second one left **Private** — this is what you'll assign directly
  to a client via "My Cards" → toggle to "Habits" → tap "Assign" on that row.
- Both need at least one active `coaching_relationships` row between that
  trainer and a test client account (Milestone 2's manual steps cover
  creating one by hand if you haven't already).

## 6. What still needs a live project + the steps above to actually verify

- Migration 015's edited RLS specifically — the `exists` check gating
  `template_id` to public/published/approved templates is untested against
  real data. Confirm: a client CAN adopt a public+published+approved
  template, and CANNOT insert a habit pointing at a private or draft one (try
  crafting a raw REST insert with a private template's id — it should be
  rejected, not silently accepted).
- The `assign_habit_template()` RPC and its two `raise exception` branches
  (`TEMPLATE_NOT_FOUND_OR_NOT_OWNED`, `NO_ACTIVE_RELATIONSHIP`) — only
  reviewed by hand and `deno check`/`flutter analyze`/`flutter test` so far,
  same untested-against-a-real-token caveat every prior Edge Function's
  manual steps have flagged.
- The full trainer-push loop: Build → Habit Template → save as private →
  My Cards → Habits toggle → Assign → pick a client → the client's Today and
  Progress screens both show it (as `trainer_assigned`, with the trainer's
  template's title/type/target copied over).
- The full client-adopt loop: a client opens "+ Add a habit" → "Browse
  templates" → sees the public template created in step 5 → taps Add → it
  appears on Today/Progress immediately (as `self_created`, `template_id`
  set).
- The toggle wrappers (`TrainerLibraryScreen`/`TrainerBuildScreen`) against a
  real device — the `embedded` flag on `CardsListScreen`/`BuildSessionScreen`
  is new, reviewed by hand and against `flutter analyze` only; confirm
  switching the toggle mid-form doesn't leave stray state or a rendering
  glitch (expected behavior is a clean reset, not preserved-across-toggle
  form state — see Milestone 4.5.md if that turns out to be the wrong call).
- Whether `habits`' loosened RLS is actually sufficient once a second
  client/trainer account starts probing it — same "reviewed by hand, not by
  a second account" caveat every prior milestone's manual steps have
  flagged.
