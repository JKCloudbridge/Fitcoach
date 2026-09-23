# Milestone 2 — Core coaching loop

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`) without a live Supabase
project. It needs the manual steps in `Milestone 2 manual steps.md` — including
applying migrations 005-009, deploying `workout-api`, and creating at least one test
`coaching_relationships` row by hand — before it runs end-to-end.

## 1. What Was Built

**Schema** (`migrations/005-009`) — per `Initial requirement/Requirement 1`
§3.5-3.10, the snapshot pattern: assigning a card copies its `exercises` into
`assignment_exercises` at that moment, so a later template edit never rewrites an
already-assigned client's plan, and a trainer editing one client's copy never
touches the template.

- `005_create_coaching_relationships.sql` — trainer↔client connection. The doc
  gives no explicit RLS block for this table (a genuine gap in the source doc) —
  policies here are this migration's own design: either party reads their own
  relationship, and a trainer can insert one directly for themselves, since
  there's no invite/consent flow yet (`redeem-invite` is Milestone 7's gym-seat
  work). **Deliberately permissive for MVP** — revisit once Milestone 7 ships.
- `006_create_workout_cards_and_exercises.sql` — the trainer-authored template.
  RLS exactly as given in the doc (public/own/gym_only visibility chain).
  `cover_media_id`/`intro_media_id`/`demo_media_id` are plain nullable `uuid`
  columns with **no FK to `media_assets`** — that table doesn't exist until a
  later milestone (media upload is out of scope here, same as Milestone 1's
  read-only `avatar_url`). `moderation_status` defaults to `'approved'` since
  `moderate-card` isn't built yet.
- `007_create_workout_assignments_and_assignment_exercises.sql` — the link
  between template and client, plus its exercise snapshot.
  `workout_assignments` has **no INSERT policy or grant for `authenticated`** —
  creation only happens through the `assign-workout-card` RPC under the
  service-role connection, per CLAUDE.md's hybrid pattern. Direct RLS `UPDATE`
  is allowed (e.g. a client archiving their own plan). Trainers can
  insert/update/delete `assignment_exercises` for their own assignments
  (adjusting one client's weight/notes without touching the template).
- `008_create_workout_logs.sql` — "what actually happened," scoped to
  `assignment_exercise_id` and `log_date`, never to the template directly.
- `009_assign_workout_card_function.sql` — `assign_workout_card()`, a
  `security definer` Postgres RPC modeled on Proximity's `rpc_place_order`
  (cart → order is the same "snapshot at a point in time" shape as
  card → assignment here). Validates the card belongs to the calling trainer
  and an active `coaching_relationships` row exists, then inserts the
  assignment and snapshots its exercises in one transaction. Only callable via
  the service-role connection (`revoke execute ... from public, anon,
  authenticated`). **Deliberately skips the "notify client" step** the doc's
  §6.6 mentions — the `notifications` table doesn't exist until Milestone 6.

Every new-table migration includes the explicit `grant` block required from
2026-10-30 on (Supabase stops auto-granting Data API access to new public tables
— see the project memory note), adjusted per table to match its actual RLS intent
(e.g. no `anon` grant on tables that always require a signed-in trainer/client).

**Backend** (`fitcoach_backend/` — new, the first Edge Function in the project):

```
fitcoach_backend/
├── deno.json                     — npm: import pins (hono, zod, @hono/zod-validator, @supabase/supabase-js)
├── .env.example
└── supabase/functions/
    ├── _shared/
    │   ├── supabaseAdmin.ts      — service-role client factory
    │   ├── auth.ts               — authMiddleware + requireRole('trainer'|'client')
    │   └── errors.ts             — {data}/{error:{code,message}} envelope helper
    └── workout-api/index.ts      — POST /assign-workout-card
```

The auth/validation middleware is patterned directly on Proximity's
`proximity_backend/supabase/functions/api/middleware/auth.ts` (the only approved
reference app for this milestone) — `supabaseAdmin.auth.getUser(token)` to verify
the bearer token, plus a manual decode of the token's own payload for the
hook-injected `app_metadata.role` claim (migration 004's
`custom_access_token_hook`), since `getUser()` alone only returns
`auth.users.raw_app_meta_data`, not what the hook stamps into the signed JWT.
**Adapted, not copied verbatim**: FitCoach deploys several small domain
functions instead of Proximity's one monolithic `api` function, and has no
Drizzle dependency in its stack, so `assign_workout_card` is called via plain
`supabase-js` `.rpc()` rather than Drizzle's raw-SQL escape hatch.

`POST /workout-api/assign-workout-card` — trainer-only (`requireRole('trainer')`),
body `{ cardId, clientId, startDate?, dueDate? }` (zod-validated), maps the RPC's
`RAISE EXCEPTION` codes (`CARD_NOT_FOUND_OR_NOT_OWNED`, `NO_ACTIVE_RELATIONSHIP`)
to `404`/`409` via a lookup table, returns `{ data: { assignmentId } }` on `201`.

**Flutter app** (`fitcoach_app/lib/features/`):

- `workout_cards/` (trainer) — `WorkoutCard`/`Exercise` models; direct-Supabase
  repository (own-row CRUD, RLS-gated, no Edge Function needed for editing a
  template you own); `CardsListScreen` (`/trainer/cards`, replaces its
  `ComingSoonScreen`) with an "Assign" action per card; `BuildSessionScreen`
  (`/trainer/build` for a new card, `/trainer/cards/:cardId` for editing an
  existing one) — title/description/visibility/difficulty/published form fields
  plus an inline growable exercise-row list (name/sets/reps/weight_kg/rest,
  add/remove/move-up-down); `AssignCardSheet` — picks from the trainer's active
  `coaching_relationships`, calls `assign-workout-card` via `dioProvider`.
- `coaching/` — `CoachingRelationshipsRepository.fetchActiveClients()`, the
  minimal read the assign flow needs. Not a roster/"Clients" tab feature — that
  tab is still a `ComingSoonScreen`, explicitly out of scope.
- `assignments/` (client) — `WorkoutAssignment`/`AssignmentExercise` models;
  `AssignmentsRepository.fetchActiveAssignment()` (direct RLS read of the
  client's most-recently-assigned active plan); `TodaySessionScreen`
  (`/client`, replaces its `ComingSoonScreen`) — merges the assignment's
  exercises with today's `workout_logs` via the pure `mergeExercisesWithLogs()`
  function to derive per-row done/not-done (done-ness isn't a stored column,
  it's whether a log exists for today's date).
- `workout_logs/` (client) — direct-Supabase repository (own-row insert/update,
  RLS-gated); `LogSetSheet` — bottom sheet pre-filled with the exercise's
  planned sets/reps/weight, editable, plus optional RPE/notes.

`core/router/app_router.dart` — the three `ComingSoonScreen` placeholders at
`/client`, `/trainer/cards`, and `/trainer/build` are now real screens, same
route paths; `/trainer/cards` gained a `:cardId` child route for editing.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 33 tests passing (redirect logic, profile/workout-card/
      assignment/workout-log model parsing, `mergeExercisesWithLogs`, and both
      Milestones 0-1's existing suites)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/`
- [x] `workout_cards` + `exercises` schema, RLS, and Data API grants
- [x] `coaching_relationships` schema, RLS, and Data API grants
- [x] `workout_assignments` + `assignment_exercises` snapshot-pattern schema,
      RLS, and Data API grants
- [x] `workout_logs` schema, RLS, and Data API grants
- [x] `assign_workout_card()` RPC — validates ownership + active relationship,
      snapshots exercises, locked to the service-role connection
- [x] `fitcoach_backend/workout-api` — first Edge Function, auth/validation
      middleware built from scratch per Proximity's pattern
- [x] Trainer "Build the session" screen — create/edit a card + its exercises
- [x] Client "Today's session" screen — active assignment, log a set
- [ ] Migrations 005-009 applied to a live Supabase project — **you** need to
      do this first (see manual steps doc)
- [ ] `workout-api` deployed — **you** need to do this first (see manual steps
      doc)
- [ ] A live device/emulator run of the full loop (trainer builds a card →
      assigns it → client logs a set → the row shows as done) — not yet run,
      no live project exists yet and no test `coaching_relationships` row
      exists to assign against

## 3. Known Gaps / Deliberate Non-Scope

- **No invite/consent flow for `coaching_relationships` yet.** A trainer can
  insert a relationship row directly (RLS-allowed), with no client-side
  acceptance step — that's `redeem-invite`, Milestone 7's gym-seat work. Until
  then, connecting a test trainer and client requires a manual SQL insert (see
  manual steps doc).
- **`assign-workout-card`'s "notify client" step is not implemented.** The doc's
  §6.6 describes inserting a notification; the `notifications` table doesn't
  exist until Milestone 6. Deferred, not forgotten.
- **`TodaySessionScreen` doesn't disambiguate multiple concurrent active
  assignments** — it shows the single most-recently-assigned active plan.
  Self-directed assignments (`follow-public-card`, source `self_saved`) aren't
  built this milestone (that's Discover, Milestone 3), so there's at most one
  active assignment per client in practice today.
- **No wearable stat row on Today's session** — the UI concept's mock steps/HR
  display was deliberately left out rather than faked; `wearable_metrics`
  doesn't exist until Milestone 5.
- **Repository classes aren't unit-tested.** FitCoach has no mocking
  infrastructure yet (Milestones 0-1's tests are all pure-function/model-level,
  no mockito/mocktail in the dependency set) — Milestone 2's tests follow the
  same convention rather than introducing one. `WorkoutCardsRepository`,
  `AssignmentsRepository`, `WorkoutLogsRepository`, and
  `AssignWorkoutCardRepository` are exercised only by the live device run once
  a project exists, not by `flutter test`.
- **`replaceExercises`/checkout-adjacent writes aren't transactional at the app
  layer.** A trainer's own-card exercise-list save is a delete-then-insert pair
  of direct Supabase calls, not a single RPC — acceptable for single-owner data
  with no cross-user contention, unlike `assign-workout-card`'s multi-table,
  cross-user write, which is why that one *is* an RPC.
- Discover, habits, wearables, messaging, seats, and the marketplace remain
  entirely out of scope, per this milestone's own instructions.
