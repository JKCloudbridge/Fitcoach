# Milestone 3 — Discover & self-directed

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`) without a live Supabase
project. It needs the manual steps in `Milestone 3 manual steps.md` — including
applying migrations 010-013 and deploying the updated `workout-api` — before it runs
end-to-end. Also assumes Milestone 2's own manual steps (migrations 005-009,
`workout-api`'s first deploy, a test `coaching_relationships` row) are already done.

## 1. What Was Built

**Schema** (`migrations/010-013`) — per `Initial requirement/Requirement 1`
§3.11, §3.15-3.16, §6.5-6.6:

- `010_create_card_stats.sql` — the 1:1 aggregates row per `workout_cards`
  (`view_count`/`save_count`/`follow_count`/`completion_count`/`share_count`).
  Per the doc's own words ("written only by an Edge Function"), there is no
  `insert`/`update`/`delete` grant for `authenticated` at all — every write
  goes through a `security definer` function, same lock-down shape as
  Milestone 2's `assign_workout_card()`. A new `AFTER INSERT` trigger on
  `workout_cards` auto-creates a zeroed `card_stats` row for every card, so
  every later increment is a plain `UPDATE` against a row guaranteed to
  already exist — no upsert-or-race handling needed anywhere else.
  `view_count`/`completion_count`/`share_count` stay at 0 this milestone —
  there's no natural "card view" event on a screen that just lists cards, and
  completion tracking would mean reaching back into `workout_logs`, which
  Plan.md's own sequencing deliberately avoids re-touching from Milestone 3+.
  Deferred, not forgotten.
- `011_create_saved_cards.sql` — the pure bookmark table, `(client_id,
  card_id)` PK. Unlike `workout_assignments`, this one **is** direct-RLS
  insert/delete (the doc's own §6.5 lists it as a plain REST call, not an Edge
  Function route) — bookmarking your own card is single-owner data, no
  cross-user transactional logic. A trigger keeps `card_stats.save_count` in
  sync on insert/delete.
- `012_create_card_reports.sql` — the "basic moderation flag" this
  milestone's scope calls for, **not** a moderation UI. Insert-only: any
  signed-in user can file a report for themselves; there is no select policy
  or grant for `authenticated` at all, since there's no admin role/claim
  anywhere in the project yet and `moderate-card`/`moderation-api` stay
  deferred per `Plan.md`'s open decisions. Reports are write-only from the
  client's perspective until an admin surface exists to read them back.
- `013_follow_public_card_function.sql` — `follow_public_card()`, the
  self-directed analog of migration 009's `assign_workout_card()`. Same
  "validate everything, then snapshot in one transaction" shape, reused
  directly per this milestone's own instructions rather than a different
  pattern: checks the card is genuinely `public`/`is_published`/`approved`,
  guards against re-following an already-active self-saved assignment,
  inserts `workout_assignments` (`source = 'self_saved'`, `trainer_id`/
  `org_id`/`relationship_id` all `null`) + its `assignment_exercises`
  snapshot, and bumps `card_stats.follow_count` **in the same transaction** —
  a decision, not an oversight: Plan.md's own instructions asked whether
  `update-card-stats` should be a synchronous side-effect or a separate
  mechanism, and a whole extra scheduled/Edge Function path for a one-line
  counter bump would be over-building it. `save_count` (migration 011) is
  handled the same "no separate job" way, via a DB trigger instead, since
  `saved_cards` writes happen directly from the client, not through this RPC.

Every new-table migration includes the explicit `grant` block required from
2026-10-30 on (see project memory), adjusted per table exactly like Milestone 2's
migrations were.

**Backend** (`fitcoach_backend/supabase/functions/workout-api/index.ts` — extended,
not a new function, per `Plan.md`'s §6.6 table: `follow-public-card` lands
alongside `assign-workout-card`):

`POST /workout-api/follow-public-card` — client-only (`requireRole('client')`),
body `{ cardId }` (zod-validated), maps the RPC's `RAISE EXCEPTION` codes
(`CARD_NOT_FOUND_OR_NOT_PUBLIC`, `ALREADY_FOLLOWING`) to `404`/`409` via the same
lookup-table pattern `assign-workout-card` already uses, returns
`{ data: { assignmentId } }` on `201`.

**Flutter app** (`fitcoach_app/lib/features/discover/`) — replaces `/client/discover`'s
`ComingSoonScreen`:

- `data/discover_models.dart` — `DiscoverCard`, a read-only projection of
  `workout_cards`. Whether a card is saved lives in a separate id set
  (`savedCardIdsProvider`), not a field on the model, since save state changes
  independently of the card list.
- `data/discover_repository.dart` — direct-Supabase reads/writes: public card
  listing, `saved_cards` save/unsave, `card_reports` insert. No Edge Function
  needed for any of these, per the doc's own §6.5 API section.
- `data/follow_public_card_repository.dart` — the one Dio-based call, mirrors
  `workout_cards/data/assign_workout_card_repository.dart`'s shape exactly.
- `utils/filter_discover_cards.dart` — pure function behind the filter chips,
  unit-tested without a widget test, same convention as `assignments/utils/
  merge_exercises_with_logs.dart`.
- `presentation/discover_screen.dart` — filter chips (All/Strength/Mobility/
  Conditioning, per the concept's `screenDiscover()`) **plus a trailing
  "Saved" chip** that filters the same list to bookmarked cards — there's no
  separate Saved screen, matching the concept's single-screen shape rather
  than adding one it doesn't show. Disc-card rows: a flat-color thumbnail
  placeholder (no `media_assets`/cover images yet, same deferred-upload
  precedent as Milestone 2), title/byline/difficulty tag, and a bookmark
  toggle icon.
- `presentation/card_detail_sheet.dart` — tapping a row opens this. **Not
  shown in the concept HTML** (`screenDiscover()` only has the bookmark
  toggle, no "start" affordance at all) — asked and confirmed this session:
  reuse the existing sheet-on-tap pattern (`AssignCardSheet`, `LogSetSheet`)
  rather than inventing a new interaction. Shows the card's exercises (reusing
  `workout_cards`' existing `cardWithExercisesProvider` — same RLS-gated read,
  works for a client viewing a public card), a "Start this program" CTA that
  calls `follow-public-card`, and a "Report this card" text button that opens
  a one-field reason dialog and inserts into `card_reports` — the minimal
  moderation affordance the doc's scope calls for.

`core/router/app_router.dart` — `/client/discover`'s `ComingSoonScreen` is now
`DiscoverScreen`, same route path.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 38 tests passing (5 new: `DiscoverCard.fromMap`,
      `filterDiscoverCards`, plus Milestones 0-2's existing 33)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/`
- [x] `card_stats` schema, RLS, Data API grants, and the auto-create trigger
- [x] `saved_cards` schema, RLS, Data API grants, and the save-count trigger
- [x] `card_reports` schema, RLS, Data API grants (insert-only)
- [x] `follow_public_card()` RPC — validates the card is genuinely public,
      guards against duplicate follows, snapshots exercises, bumps
      `follow_count`, locked to the service-role connection
- [x] `fitcoach_backend/workout-api` — `follow-public-card` route added
      alongside `assign-workout-card`
- [x] Client "Discover" screen — filter chips, disc-card rows, bookmark toggle
- [x] Card detail sheet — "Start this program" (follow-public-card) + "Report
      this card" (basic moderation flag)
- [ ] Migrations 010-013 applied to a live Supabase project — **you** need to
      do this first (see manual steps doc), after confirming 005-009 are
      already applied (010's trigger and 013's function both read
      `workout_cards`/`workout_assignments`/`exercises`, migrations 006-007)
- [ ] `workout-api` redeployed with the new route — **you** need to do this
      first (see manual steps doc)
- [ ] A live device/emulator run of the full loop (client browses Discover →
      taps a public card → starts it → it shows up in Today; saves a card →
      it shows under the Saved filter; files a report) — not yet run, no live
      project exists yet and no public `workout_cards` row (`visibility =
      'public'`, `is_published = true`, `moderation_status = 'approved'`)
      exists to test against

## 3. Known Gaps / Deliberate Non-Scope

- **No "start this program" affordance in the concept mockup at all.** The
  concept's `screenDiscover()` only wires up a bookmark toggle — asked the
  user how to surface `follow-public-card` given the doc requires it but the
  mockup doesn't show it; confirmed to reuse the existing tap-row-for-a-sheet
  pattern. Flagged here since it's a genuine addition beyond the reference
  mockup, not something read directly off it.
- **`view_count`, `completion_count`, `share_count` are schema-ready but never
  incremented.** No natural trigger point for a "view" on a screen that's
  just a list, and completion tracking would mean reopening `workout_logs`
  (Milestone 2's own core table) from Discover's scope — deliberately left at
  0 rather than faked or half-wired.
- **`card_reports` has no read path anywhere** — not even for the reporting
  client or the card's own trainer. There's no admin role/claim concept in the
  project yet, so the safest default was "insert-only, unreadable via the Data
  API" rather than guessing at who should see reports. `moderate-card`/
  `moderation-api` remain fully deferred, per `Plan.md`'s own open decisions.
- **No duplicate-save guard beyond the primary key.** `saved_cards`' `(client_id,
  card_id)` PK already prevents a double bookmark at the DB level; the UI
  doesn't need extra handling because the insert would just fail (surfaced as
  a generic error) — acceptable since the toggle button already reflects
  current save state from `savedCardIdsProvider`, so a double-tap race is the
  only way to hit it.
- **Discover's thumbnail is a flat placeholder color, not `cover_media_id`.**
  `media_assets` doesn't exist until a later milestone (same deferred-upload
  precedent as Milestone 2's cards) — the color is picked deterministically
  from the card's id so it's at least stable across rebuilds, not random noise.
- **`follow_public_card()` doesn't disambiguate multiple concurrent self-saved
  assignments the way `TodaySessionScreen` doesn't either** — it shows the
  single most-recently-assigned active plan (Milestone 2's own known gap).
  Starting a second public card while one is already active will make it the
  new "most recent," effectively replacing what Today shows, not stacking.
  Not addressed this milestone — flagged as inherited from Milestone 2's own
  scope note, now actually reachable since self_saved assignments exist.
- Habits, wearables, messaging, seats, the marketplace, and full moderation
  tooling remain entirely out of scope, per this milestone's own instructions.
