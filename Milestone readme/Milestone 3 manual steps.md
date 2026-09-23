# Milestone 3 — Manual Steps Required From You

Assumes Milestone 2's manual steps (migrations 005-009 applied, `workout-api`
deployed once already, a test `coaching_relationships` row) are already done. If
you haven't confirmed 005-009 are actually applied to the live project yet, do
that first — migrations 010 and 013 below both read tables those create
(`workout_cards`, `workout_assignments`, `exercises`).

## 1. Apply migrations 010-013

```
cd fitcoach_backend
supabase db query -f "../migrations/010_create_card_stats.sql" --linked
supabase db query -f "../migrations/011_create_saved_cards.sql" --linked
supabase db query -f "../migrations/012_create_card_reports.sql" --linked
supabase db query -f "../migrations/013_follow_public_card_function.sql" --linked
```

Run them in this order — 011's trigger writes to `card_stats` (010), and 013's
function reads `workout_cards`/`exercises`/`workout_assignments` (Milestone 2's
005-007) and writes to `card_stats` (010). No backfill needed for 010's
auto-create trigger: `workout_cards` has 0 live rows as of this milestone (the
last confirmed state), so there are no pre-existing cards that would be missing a
`card_stats` row.

## 2. Redeploy the `workout-api` Edge Function

```
cd fitcoach_backend
supabase functions deploy workout-api
```

Same function as Milestone 2, not a new one — this just ships the new
`follow-public-card` route added to the existing `index.ts`. No new secrets
needed (still just the auto-injected `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`).

## 3. Create at least one real public workout_card to test against

Discover only shows rows where `visibility = 'public'`, `is_published = true`,
and `moderation_status = 'approved'`. `moderation_status` already defaults to
`'approved'` (migration 006 — moderation isn't enforced yet), so a trainer
account just needs to build a card via `BuildSessionScreen` with visibility set
to **Public** and **Published** turned on. Without at least one such card,
Discover will correctly show its empty state, but you won't be able to test the
save/start/report flows.

## 4. Confirm `fitcoach_app/.env`

Nothing new was added to `.env`'s shape this milestone — same
`EDGE_FUNCTIONS_BASE_URL` from Milestone 0 covers the new `follow-public-card`
route too (it's the same `workout-api` function). No `build_runner` re-run needed.

## 5. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

## 6. What still needs a live project + the steps above to actually verify

- Migrations 010-013 actually applying cleanly against a real Postgres instance
  — the `card_stats` auto-create trigger, the `saved_cards` save-count trigger,
  and the `follow_public_card()` RPC are all untested against real data, only
  reviewed by hand and `deno check`/`flutter analyze`/`flutter test` so far.
- `follow-public-card` actually deployed and reachable — same untested-against-a-
  real-token caveat Milestone 2's manual steps flagged for `assign-workout-card`.
- A client opening Discover and actually seeing the public card created in step 3
  — confirms the `workout_cards` visibility/moderation filter and the
  `trainer_profiles` join both work against real data.
- The bookmark loop: tapping the save icon → a `saved_cards` row appears →
  `card_stats.save_count` increments (check via `select * from card_stats`) →
  the "Saved" filter chip shows the card → unsaving removes it and decrements
  the count back.
- The full follow loop: tapping a card → the detail sheet loads its exercises →
  "Start this program" → `follow_public_card()` succeeds → a `workout_assignments`
  row (`source = 'self_saved'`) + its `assignment_exercises` snapshot appear →
  `card_stats.follow_count` increments → the card now shows up in
  `TodaySessionScreen` (client's `/client` tab).
- The report flow: "Report this card" → a `card_reports` row appears with
  `status = 'open'` — there's no UI to see it back (see Milestone 3.md §3), so
  this can only be confirmed by querying the table directly.
- Whether `card_stats`' `select`-only RLS (readable wherever the parent card is
  readable, no write policy for `authenticated` at all) is actually sufficient
  once a second client/trainer account starts probing it — same "reviewed by
  hand, not by a second account" caveat Milestone 2's manual steps flagged for
  `coaching_relationships`/`workout_assignments`.
