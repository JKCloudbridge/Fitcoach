# Milestone 2 — Manual Steps Required From You

Assumes Milestones 0-1's manual steps (Supabase project created, migrations
001-004 applied, JWT hook enabled, Google OAuth + Email OTP working) are already
done.

## 1. Apply migrations 005-009

```
cd fitcoach_backend
supabase db query -f "../migrations/005_create_coaching_relationships.sql" --linked
supabase db query -f "../migrations/006_create_workout_cards_and_exercises.sql" --linked
supabase db query -f "../migrations/007_create_workout_assignments_and_assignment_exercises.sql" --linked
supabase db query -f "../migrations/008_create_workout_logs.sql" --linked
supabase db query -f "../migrations/009_assign_workout_card_function.sql" --linked
```

Run them in this order — each references tables created by an earlier one
(`exercises` → `workout_cards`, `assignment_exercises` → `workout_assignments` →
`coaching_relationships`, and 009's function reads `exercises`/`workout_cards`/
`coaching_relationships`).

## 2. Deploy the `workout-api` Edge Function

```
cd fitcoach_backend
supabase functions deploy workout-api
```

This is the first Edge Function in the project — deploying it creates the
function at `https://<your-project-ref>.supabase.co/functions/v1/workout-api`.
Supabase automatically injects `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
into every deployed Edge Function — no `supabase secrets set` needed for those
two. `fitcoach_backend/.env.example` (copy to `.env`) is only needed if you want
to run it locally first with `supabase functions serve workout-api --env-file .env`.

## 3. Create a test `coaching_relationships` row

There is no invite/consent flow yet (that's Milestone 7's gym-seat work), so
`assign-workout-card` will always fail with `NO_ACTIVE_RELATIONSHIP` until a
trainer and client are connected by hand. With a trainer and client account
already signed up (Milestone 1's flow) and their `auth.users` UUIDs in hand
(Authentication → Users in the dashboard, or `select id, email from
auth.users`):

```sql
insert into coaching_relationships (trainer_id, client_id, type, status)
values ('<trainer-auth-uid>', '<client-auth-uid>', 'private', 'active');
```

Run this via the Supabase Dashboard's SQL Editor, or
`supabase db query --linked` with a small `.sql` file. Repeat for every
trainer/client pair you want to test with — do this again after any test reset
that clears the table.

## 4. Confirm `fitcoach_app/.env`

`EDGE_FUNCTIONS_BASE_URL` was already required from Milestone 0 — double check
it points at `https://<your-project-ref>.supabase.co/functions/v1` (no trailing
function name; each repository appends its own, e.g. `/workout-api/...`).
Nothing new was added to `.env`'s shape this milestone, so no `build_runner`
re-run is needed unless it changed.

## 5. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

## 6. What still needs a live project + the steps above to actually verify

- Migrations 005-009 actually applying cleanly against a real Postgres instance
  (RLS policies and the `assign_workout_card` RPC are untested against real
  data — only reviewed by hand and `deno check`/`flutter analyze`/`flutter test`
  so far)
- `workout-api` actually deployed and reachable — the auth middleware's
  `supabaseAdmin.auth.getUser(token)` call and the JWT-payload decode for the
  `role` claim have never run against a real token
- A trainer building a card in `BuildSessionScreen`, saving it, and it showing
  up in `CardsListScreen`
- The full assign loop: trainer taps "Assign" on a card → picks the test client
  from step 3 → `assign-workout-card` succeeds → a `workout_assignments` +
  `assignment_exercises` row actually appears
- The client side of that loop: the assigned card showing up in
  `TodaySessionScreen`, tapping an exercise opening `LogSetSheet`, logging a set
  writing a `workout_logs` row, and the row flipping to "done" after
  `todayLogsProvider` refetches
- Whether the `coaching_relationships`/`workout_assignments` RLS policies are
  actually permissive/restrictive enough in practice — they're this milestone's
  own design where the source doc didn't specify exact policy text (see
  Milestone 2.md §3), so they haven't been validated against a second trainer
  or client account probing for over-exposure
