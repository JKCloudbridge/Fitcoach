# Milestone 8 — Marketplace & payouts

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`, and a rollback-wrapped
`BEGIN; ...; ROLLBACK;` dry-run of the full pending migration chain against the live
linked project to catch SQL errors early) without committing anything to the live
database. Needs the manual steps in `Milestone 8 manual steps.md` — applying
migrations 023-029 (and everything still pending ahead of them, 010-022) and the
first-ever deploy of `programs-api`.

Builds `programs`/`program_habits`/`program_subscriptions`/`payouts` (Requirement 1
§11), the `subscribe-program` connection flow (§11.3, self-serve stub — see below),
the paid-content RLS gating (§11.7), and the marketplace Flutter feature (client:
paid Discover listing, program detail, "My Programs"; trainer: bundle an existing
workout_card + habit_templates into a program, price it, publish). This is the last
milestone on Plan.md's roadmap (§11). Branched as `M8` off `main`'s tip
(`origin/M8`, itself branched from `main`'s post-M7-merge tip — M7 was merged
directly into `main` via PR #5 between sessions, confirmed via `git log`/`git fetch`
before starting; `origin/M8` was already sitting at that same tip with no commits of
its own).

## 0. Scope decisions made this session

Four questions were flagged before writing any code (per this milestone's own task
framing, mirroring M7's own "ask before building" pattern) and confirmed with the
person before building:

1. **Payment collection for `subscribe-program`**: confirmed **self-serve stub**,
   same posture as Milestone 7's seat subscriptions. `razorpay_flutter` was
   re-confirmed absent from `pubspec.yaml` before asking (still true as of this
   session). `subscribe-program` creates `program_subscriptions` directly with
   `price_paid_inr` copied straight from `programs.price_inr` — no gateway charge
   collected. `program-payment-webhook` (§13's other listed endpoint, for when a real
   gateway confirms payment) was **not built** this milestone — same "don't build
   both blindly" call M7 made for gym-seat billing. Flagged on-screen in the program
   detail sheet and in the manual steps doc.
2. **`run-payouts` / real money movement**: confirmed **data-only**, per Plan.md's
   own explicit instruction (§11.8's compliance note — splitting a client payment
   between the platform and a coach falls under RBI's Payment Aggregator
   regulations in India). `run-payouts` aggregates `program_subscriptions` revenue
   per trainer for a period, applies the platform fee, and writes a `payouts` row
   with `status = 'pending'`. **No gateway payout call anywhere in this codebase.**
   This is not a stub that will silently start moving money later without a change —
   there's no code path there to move it. Do not add one without the CA/fintech-
   consultant sign-off §11.8 requires.
3. **Platform fee**: confirmed **15%** (the low end of §11.6's stated 15–25% range).
   A plain constant (`PLATFORM_FEE_RATE` in `programs-api/index.ts`) — trivial to
   change later, not a schema decision.
4. **Payout cadence**: confirmed **monthly, with a ₹500 minimum threshold** (held/
   skipped rather than paid out) — §11.6's own stated common middle ground. Affects
   how `run-payouts` would be scheduled once cron is wired up (see manual steps doc);
   doesn't affect anything at the schema level.

## 1. What Was Built

**Schema** (`migrations/023-029`):

- `023_create_programs_and_program_habits.sql` — `programs`, `program_habits`.
  `moderation_status` defaults to `'approved'`, same precedent `workout_cards`
  (006)/`habit_templates` (014) already set — not a new decision, consistency with
  what's already shipped, per this milestone's own framing. `billing_period`
  defaults to `'one_time'` (the doc gives no default; the simpler MVP shape given
  `subscribe-program` is a stub with no real recurring billing). A
  `BEFORE INSERT OR UPDATE` trigger (`validate_program_workout_card()`) checks a
  program's `workout_card_id`, when set, actually belongs to the same trainer —
  same "closes an obvious integrity gap" call M7's `validate_subscription_owner()`
  made. `program_habits_write` RLS similarly requires the bundled `habit_template_id`
  to belong to the program's own trainer — bundling someone else's template into
  your paid program would let you sell content you don't own.
- `024_create_program_subscriptions.sql` — `program_subscriptions`. No INSERT/UPDATE
  policy for `authenticated` at all — creation (028) and status changes (029) are
  both RPC-only via the service-role connection, same "no direct INSERT policy"
  shape `workout_assignments` (007) already established. A unique partial index
  (`(client_id, program_id) where status = 'active'`) guards a double-subscribe race
  beyond `subscribe_program()`'s own existence check, same defense-in-depth call
  M7's owner-validation trigger made.
- `025_create_payouts.sql` — `payouts`. No write policy for `authenticated` at all —
  every row is system-generated by `run-payouts`' service-role connection. Read-only
  for the earning trainer, or an active owner/admin org member.
- `026_add_program_subscription_id_columns.sql` — additive `ALTER TABLE` adding
  `program_subscription_id` to `workout_assignments` (007) and `habits` (015), per
  §11.3's closing note — neither already-shipped migration file touched in place,
  same rule this project has followed since migration 020.
- `027_extend_paid_content_rls.sql` — extends `exercises_select` (006) and
  `habit_templates_select` (014) per §11.7's paid-gating pattern. §11.7's own SQL
  only shows the paid-gating clause in isolation, without restating §4's visibility
  chain — read here as **composing with it (AND)**, not replacing it: a paid
  program's exercises/habit-template detail need both "the card/template is visible
  at all" (unchanged) and "you're allowed past the paywall" (new) to pass. The
  alternative (OR) would make the new clause pointless. Same pattern extended from
  `exercises` to `program_habits → habit_templates`, per §11.7's own closing line.
  Not editable in place (006/014 are already live) — the existing policy objects are
  dropped and recreated in this new migration, safe for RLS specifically (a policy
  is just a rule re-evaluated per query, no data migration involved).
- `028_subscribe_program_function.sql` — `subscribe_program(p_client_id, p_program_id)`.
  Modeled directly on `assign_workout_card()` (009)/`follow_public_card()` (013) —
  validate everything first, then write in one transaction: `program_subscriptions`
  row, then (if `workout_card_id` is set) a `workout_assignments` row + exercise
  snapshot, then a `habits` row per `program_habits` entry — all tagged
  `program_subscription_id`. Unlike `assign_workout_card()`, there's **no**
  `coaching_relationships` check — a program purchase is the marketplace's own,
  independent entry point into the execution layer (§12), not a coaching
  connection; `relationship_id` stays null on the resulting assignment.
- `029_expire_program_subscriptions_function.sql` — `expire_program_subscriptions()`.
  Flips a `'monthly'` subscription whose `current_period_end` has passed to
  `'canceled'` (no real recurring billing exists to renew it), then archives every
  `workout_assignments`/`habits` row tagged with a now-inactive subscription's id.
  Idempotent — safe to call repeatedly. `'one_time'` rows have
  `current_period_end = null` and are never touched (permanent access by design).

**Backend** (`fitcoach_backend/supabase/functions/programs-api/`, **new function —
first deploy**):

- `POST /programs-api/subscribe-program` — client-only (`requireRole("client")`).
  Same `zValidator`/`mapRpcError` shape as every other Edge-Function-only write in
  this project. Three typed error codes (`CLIENT_NOT_FOUND`,
  `PROGRAM_NOT_FOUND_OR_NOT_PUBLISHED`, `ALREADY_SUBSCRIBED`).
- `POST /programs-api/expire-program-subscriptions` — thin wrapper around migration
  029's function. Gated by a **new** `requireServiceRole` middleware
  (`_shared/auth.ts`), not the usual `authMiddleware` — this route is meant to be
  invoked by Supabase Cron (or manually) with the service-role key, not a signed-in
  user's JWT, which `authMiddleware`'s `auth.getUser()` call would reject outright.
  This is the **first scheduled/cron-shaped job anywhere in this project** — actual
  schedule wiring is a manual step, see below.
- `POST /programs-api/run-payouts` — also `requireServiceRole`. Takes `periodStart`/
  `periodEnd`, aggregates `program_subscriptions.price_paid_inr` per trainer (plain
  TypeScript grouping over a service-role read — no SQL RPC needed here, since
  service_role already bypasses RLS on both reads and the `payouts` insert), applies
  the 15% fee, skips (holds) any trainer whose net amount falls under the ₹500
  threshold, writes a `'pending'` `payouts` row per trainer above it. **No gateway
  payout call anywhere in this route or anywhere else in this codebase.**
- `deno check` clean across all four functions (`workout-api`, `coaching-api`,
  `habits-api`, `programs-api`).

**Flutter app**, new `lib/features/programs/`:

- `data/program_models.dart` — `Program` (mirrors `WorkoutCard`/`HabitTemplate`'s
  shape, with bundled habit-template ids/titles read off a nested
  `program_habits(habit_templates(...))` select) and `ProgramSubscription`.
- `data/programs_repository.dart` — direct-RLS CRUD on `programs`/`program_habits`
  (list/detail reads, create/update, whole-list `replaceProgramHabits`), same
  "single-owner CRUD, no Edge Function needed" precedent as
  `WorkoutCardsRepository`/`HabitTemplatesRepository`.
- `data/subscribe_program_repository.dart` — the one Dio call, mirrors
  `follow_public_card_repository.dart`.
- `data/program_subscriptions_repository.dart` — direct-RLS read of the client's own
  subscriptions with the parent program embedded ("My Programs").
- `presentation/programs_providers.dart` — public/trainer program lists, a
  program-detail family provider, the client's subscription list, and
  `myActiveProgramIdsProvider` (drives "Subscribed" state in the UI).
- `presentation/programs_list_screen.dart` — client paid listing, folded into
  **Discover** as a second `SegmentedButton` mode ("Free Cards" / "Programs")
  alongside the existing free-card browsing — same "toggle between two content
  types inside one tab" convention `TrainerLibraryScreen`/`TrainerBuildScreen`
  already established for cards vs. habit templates, rather than adding a new
  bottom-nav destination.
- `presentation/program_detail_sheet.dart` — tap-to-open bottom sheet (same
  sheet-on-tap pattern as `card_detail_sheet.dart`/`assign_card_sheet.dart`):
  price/billing, bundled card + habits, Subscribe button, on-screen no-payment-
  gateway notice.
- `presentation/my_programs_screen.dart` — client's subscribed-programs list.
  Reached from Client Profile only (new "My Programs" button, pushed route), same
  precedent as gym_seats' "Join with a code".
- `presentation/trainer_programs_list_screen.dart` — trainer's own programs list,
  folded into `TrainerLibraryScreen` as a third segment ("Workout Cards" / "Habits" /
  "Programs").
- `presentation/build_program_screen.dart` — trainer builder: title/description/
  price/billing period, a dropdown over the trainer's *own* workout cards
  (nullable — a program can be habit-only per §11.1), a checklist over the
  trainer's *own* habit templates, publish switch. Folded into `TrainerBuildScreen`
  as a third segment ("Workout Card" / "Habit Template" / "Program") for create;
  edit is a pushed route (`/trainer/cards/programs/:programId`), same nested-route
  shape as `:cardId`/`templates/:templateId`. Unlike `BuildSessionScreen`/
  `BuildHabitTemplateScreen`, this screen doesn't author new exercise/habit content
  — it only *selects* among content that already exists, since a program bundles,
  it doesn't own.

**Router/Profile wiring** (`app_router.dart`, `client_profile_screen.dart`,
`discover_screen.dart`, `trainer_library_screen.dart`, `trainer_build_screen.dart`):

- `/client/profile/my-programs` (pushed, nested under `/client/profile`) — reached
  via a new "My Programs" button on `ClientProfileScreen`.
- `/trainer/cards/programs/:programId` (pushed, nested under `/trainer/cards`) —
  edit route for an existing program.
- Discover, `TrainerLibraryScreen`, and `TrainerBuildScreen` all gained a third
  mode/segment for programs, as described above — no new top-level routes or
  bottom-nav destinations.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 72 tests passing (4 new: `Program.fromMap` ×2,
      `ProgramSubscription.fromMap` ×2, plus the prior 68)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/`, including
      the new `programs-api` function
- [x] `programs`/`program_habits`/`program_subscriptions`/`payouts` schema + RLS,
      per §11.1-11.4
- [x] `program_subscription_id` added to `workout_assignments`/`habits` per §11.3
- [x] Paid-content RLS gating extended to `exercises` and `program_habits →
      habit_templates`, per §11.7
- [x] `subscribe_program()` RPC + `programs-api` route: validates program is
      published/approved and not already actively subscribed, then creates the
      subscription + cascades into a workout_assignments snapshot (if a card is
      bundled) + a habits row per bundled habit template, all tagged
      `program_subscription_id`, in one transaction
- [x] `expire_program_subscriptions()` RPC + callable route: lapses monthly
      subscriptions past their period end, archives their tagged assignments/habits
- [x] `run-payouts` route: aggregates revenue per trainer, applies the 15% platform
      fee, writes `'pending'` payout rows, holds anything under the ₹500 threshold —
      **no real money movement anywhere**
- [x] A rollback-wrapped dry-run of the full pending migration chain (010-029, since
      010-022 aren't live yet either — see manual steps doc) against the live linked
      project confirmed no SQL errors before handing off the real apply step
- [x] Client-side: paid Discover listing, program detail sheet, "My Programs"
- [x] Trainer-side: program builder (bundle existing card + habit templates, price,
      publish), programs list
- [ ] Migrations 023-029 (and 010-022 ahead of them) actually applied to the live
      Supabase project — **you** need to do this (see manual steps doc)
- [ ] `programs-api` deployed for the first time — **you** need to do this
- [ ] A live device/emulator run of the full loop (trainer builds a program →
      publishes → client subscribes → workout_assignments/habits appear, paid-content
      RLS actually gates a non-subscriber) — not yet run, no live project confirmed
      for this milestone's tables yet
- [ ] `expire-program-subscriptions`/`run-payouts` actually scheduled via Supabase
      Cron — **not wired up this session**, see manual steps doc (code is callable
      and testable on-demand right now, same "code complete, needs a human to flip a
      dashboard switch" treatment FCM push got in M6)
- [ ] Real payment integration (`subscribe-program` → real Razorpay checkout,
      `program-payment-webhook`) — **not built this session**, see manual steps doc
- [ ] Real payout money movement — **explicitly out of scope**, needs a CA/fintech-
      consultant sign-off per §11.8 before any code is written for it

## 3. Known Gaps / Deliberate Non-Scope

- **No payment gateway.** Subscribing to a paid program activates access
  immediately on self-serve insert, no charge collected. Flagged on-screen in the
  program detail sheet, not just in this doc. `razorpay_flutter` is still not in
  `pubspec.yaml`.
- **No real payout money movement, anywhere.** `payouts` rows are aggregation-only,
  always land at `status = 'pending'`, and nothing in this codebase ever transitions
  one further. This is the one thing in this milestone that was explicitly
  instructed not to be guessed past — see §0 decision 2.
- **No cancel-subscription flow.** A client can subscribe but not un-subscribe from
  "My Programs" — not in this milestone's scope. `program_subscriptions.status` can
  only move to `'canceled'` via `expire_program_subscriptions()` (a lapsed monthly
  period), never by direct client action.
- **`run-payouts`' below-threshold "hold" doesn't actually roll over.** §11.6 frames
  the ₹500 minimum as "hold and roll over" to the next period. A trainer under
  threshold in a given `run-payouts` call is simply skipped that run — there's no
  ledger linking a `program_subscriptions` row to the payout it was (or wasn't)
  included in, so a real carry-forward would need that linking column, which this
  data-only stub doesn't build. Flagged as a simplification, not a real accounting
  gap, since no real money moves either way yet.
- **`run-payouts` groups by `trainer_id` only**, never attributes revenue to an org
  even when a program's `org_id` is set — `programs.org_id` is treated as
  informational (same as `workout_cards.org_id`), not an alternate payout target the
  way `subscriptions.owner_type` could split trainer- vs. org-owned seat licenses in
  M7. Revisit if gym-run programs need org-level payouts later.
- **Supabase Cron isn't configured.** `expire-program-subscriptions`/`run-payouts`
  are reachable/testable on demand via `requireServiceRole`, but nothing calls them
  on a schedule yet. First scheduled-job attempt in this project — see manual steps.
- **No moderation UI**, unchanged — `moderate-card`/`moderation-api` stay deferred,
  same as every prior milestone. `programs.moderation_status` defaults to
  `'approved'` with nothing enforcing it, same "schema-ready, not wired up"
  precedent as `workout_cards`.
- Wearables (M5/M5.5), the gym-admin/organization-owned-subscription UI M7 flagged,
  and real payment/payout integration remain entirely out of scope, unchanged by
  this milestone.
