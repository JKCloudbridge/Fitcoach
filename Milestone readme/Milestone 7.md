# Milestone 7 — Gym seat licensing

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`, and a rollback-wrapped
`BEGIN; ...; ROLLBACK;` dry-run of both new migrations against the live linked
project to catch SQL errors early) without committing anything to the live database.
Needs the manual steps in `Milestone 7 manual steps.md` — applying migrations 021-022
and redeploying `coaching-api`.

Builds `subscriptions`/`invites` (Requirement 1 §10.1-10.2), the `redeem-invite`
connection flow (§10.3), and the gym-seats Flutter feature (trainer/org-owner side:
buy a seat plan, create/manage invites; client side: redeem a code) — the "gym pays
for N client seats, coach connects real clients by invite, not by search" model.
Branched as `M7` off `main`'s tip (post-M6 merge — M6 was merged directly into
`main` between sessions, confirmed via `git log`/`git ls-remote` before starting).

## 0. Scope decisions made this session

Four questions were flagged before writing any code (per this milestone's own task
framing) and confirmed with the person before building:

1. **Payment collection**: confirmed **no payment gateway wired up**. A subscription
   row is created directly (self-serve, activates immediately) with a nice pricing UI
   (`_PlanPicker` in `subscription_screen.dart`) — the person explicitly asked for a
   real UI here even without billing behind it, so unlike some other deferred-payment
   spots in this project, effort went into the picker rather than just flagging the
   gap. Real Razorpay integration (already anticipated in Plan.md's dependency list,
   not added to `pubspec.yaml` yet) is a pending follow-up, called out on-screen in
   the picker itself ("No payment gateway is wired up yet...") and in the manual
   steps doc.
2. **Who can create a subscription/invite for a gym** (owner_type = 'organization'):
   confirmed **owner/admin only** (organization_members role). See §1's RLS notes for
   how this interacts with the invite-creator-must-be-a-trainer requirement below.
3. **QR codes**: confirmed **text/link code only for v1** — no `qr_flutter`/
   `mobile_scanner` added to `pubspec.yaml`, no camera permissions. §10.2's "shareable
   as a link, code, or QR" is satisfied by the plain 8-character code shown/copied
   from the invite list. QR flagged as a follow-up in the manual steps doc.
4. **Where redemption lives in the UI**: confirmed **Profile screen only** — an
   already-onboarded client enters a code from `ClientProfileScreen`. Not wired into
   onboarding/role-select; Plan.md's onboarding flow doesn't mention invite codes.

One more design call, not in the original open-decisions list, forced by the schema
itself: **which trainer does a gym-mode (`owner_type = 'organization'`) redemption
connect the client to?** `coaching_relationships.trainer_id` is not-null, but the
doc's own `invites` schema (§10.2) has no per-invite trainer column, and decision 2
above restricts who can *create* an org invite to owner/admin — who aren't
necessarily trainers themselves. Resolved as: `invites.created_by` becomes
`coaching_relationships.trainer_id` on redemption, and migration 021's
`invites_insert` RLS policy requires the creator to **also** hold a `trainer_profiles`
row (on top of being org owner/admin), so whoever creates an org invite is always
someone who can legitimately become the assigned trainer. `redeem_invite()` (migration
022) re-checks this at redemption time rather than trusting the RLS policy was never
loosened. **Known gap, flagged rather than silently handled**: a gym owner/admin who
isn't personally a trainer can manage the subscription (buy seats, see usage) but
cannot personally issue invite codes — a teammate with both an org owner/admin role
and a trainer_profiles row has to do that, or this needs revisiting (e.g. a future
`invites.trainer_id` column) if gyms need non-training staff issuing codes.

## 1. What Was Built

**Schema** (`migrations/021-022`):

- `021_create_subscriptions_and_invites.sql` — `subscriptions`, `invites`.
  - `owner_id` (§10.1's own note: can't be a real FK across two tables) gets a
    `BEFORE INSERT OR UPDATE` trigger (`validate_subscription_owner()`) checking it
    actually resolves against `trainer_profiles`/`organizations` per `owner_type`,
    rather than leaving it purely app-layer as the doc describes — cheap to add,
    closes an obvious integrity gap since every RLS policy below joins back through
    one of those two tables anyway.
  - `seats_used` is maintained **directly by `redeem_invite()`** (migration 022's
    explicit `update` step), not a trigger on `coaching_relationships` insert/delete —
    §10.1 says "trigger", §10.3's flow describes it as an explicit RPC step; the RPC
    step was picked because a trigger would also need to handle relationships ended
    *outside* this flow (a future "pause/end coaching relationship" feature) to stay
    accurate, which is more moving parts than this milestone needs. **Known gap**:
    `seats_used` currently only ever increments — there's no decrement path yet,
    since no end-relationship flow exists anywhere in the app yet either.
  - `code` is DB-generated (`generate_invite_code()`, an 8-char uppercase hex string,
    column default) — the client never sends a code, it reads back whatever the
    insert returned. No collision-retry loop (same "don't over-build" call as other
    MVP passes in this project); the `unique` constraint rejects a collision outright
    rather than silently overwriting another invite, and the odds at 4.3B
    combinations are not worth more machinery yet.
  - RLS: `subscriptions` readable by the owning trainer or any active member of the
    owning org; writable (insert + a column-grant-limited update excluding
    `seats_used`) only by the owning trainer or org owner/admin. `invites` readable by
    creator or the subscription's owner-side; insertable only by someone who is both
    (owning trainer, or org owner/admin) **and** a `trainer_profiles` holder (see §0's
    design note); update narrowed to the `status` column only (revoke), via grant —
    same shape as migration 018/019's `read_at`/`status` column grants.
  - Data API grants per the project's standing rule (memory:
    project-supabase-data-api-grants) — no `anon` grant on either table.
- `022_redeem_invite_function.sql` — `redeem_invite(p_client_id, p_code)`. Modeled
  directly on migration 009's `assign_workout_card()` / migration 018's
  `start_conversation()` shape: validate everything first (invite exists/active/not
  expired/not exhausted, subscription active, seats available, resolved trainer_id is
  a real trainer, not already connected), then write in one transaction — insert
  `coaching_relationships` (`type = 'gym'` + `org_id` set if `owner_type =
  'organization'`, else `type = 'private'`), increment `invites.uses_count` and
  `subscriptions.seats_used`. `for update` row locks on the invite and subscription
  rows guard the last-seat race (two clients redeeming the same code as the final
  seat frees up simultaneously) — same reasoning Proximity's `rpc_place_order` uses.
  `security definer`, revoked from `public`/`anon`/`authenticated` — only reachable
  via `coaching-api`'s service-role connection.

**Backend** (`fitcoach_backend/supabase/functions/coaching-api/`, existing function
from Milestone 6 — this is a new route added to it, not a new function):

- `POST /coaching-api/redeem-invite` — client-only (`requireRole("client")`, per
  §13's "POST, client app"). Same `zValidator`/`mapRpcError` shape as
  `start-conversation`; nine typed error codes mapped to HTTP statuses
  (`INVITE_NOT_FOUND` 404, `SEATS_FULL` 409, etc.) — see the route for the full list.
  `deno check` clean alongside `workout-api`/`habits-api`/the rest of `coaching-api`.

**Flutter app**, new `lib/features/gym_seats/`:

- `data/gym_seats_models.dart` — `Subscription`, `Invite`, and `PlanTierOption` (a
  plain data class for the three self-serve tiers — `starter_50`/`growth_100`/
  `pro_250`, using the doc's own linear ₹20/seat example from §10.4, since that's the
  only concrete numbers it gives; the linear-vs-degressive pricing-ladder decision
  itself is still open per §10.4/§14, unresolved by this milestone — these are just
  placeholder row data, trivially edited later, not a schema decision).
- `data/subscriptions_repository.dart` — direct-RLS `fetchMySubscription` (trainer-
  owned only, see below) and `createSubscription` (self-serve insert, no payment
  step).
- `data/invites_repository.dart` — direct-RLS `fetchInvites`, `createInvite`,
  `revokeInvite`.
- `data/redeem_invite_repository.dart` — the one Dio call, mirrors
  `start_conversation_repository.dart`.
- `presentation/gym_seats_providers.dart` — `mySubscriptionProvider`,
  `subscriptionInvitesProvider` (family).
- `presentation/subscription_screen.dart` — trainer/org-owner side. No subscription
  yet → `_PlanPicker` (three tier cards + the "no billing yet" notice). Has one →
  usage card (progress bar, seats used/limit, status) + invite list (code, status,
  usage, copy-to-clipboard, revoke). Designed fresh following this app's existing
  list-screen convention (`AppBar` + cards/`ListView`), same situation Milestone 6 was
  in for messaging — no concept HTML screens exist for this.
- `presentation/create_invite_sheet.dart` — optional max-uses/expiry, then creates
  the invite (code is server-generated).
- `presentation/redeem_invite_screen.dart` — client side: enter a code, submit,
  success snackbar + pop back to Profile.

**Router/Profile wiring** (`app_router.dart`, `trainer_profile_screen.dart`,
`client_profile_screen.dart`):

- `/trainer/profile/subscription` (nested under the existing profile route, like
  `/trainer/profile/edit`) — reached via a new "Seats & invites" button on
  `TrainerProfileScreen`.
- `/client/profile/redeem-invite` — reached via a new "Join with a code" button on
  `ClientProfileScreen`. Both are pushed routes, not shell tabs, matching the
  `/notifications` precedent.

**Scoping call on the trainer-owned-only UI**: `subscriptions_repository.dart`'s
`fetchMySubscription` only ever reads `owner_type = 'trainer'` rows — an independent
trainer buying their own seats. `owner_type = 'organization'` (gym) subscriptions are
fully supported at the schema/RLS/RPC level (see §1's RLS notes and §0's decision 2),
but there's no gym-admin/roster screen anywhere else in this app yet to manage one
from — building that fresh here would be a much larger scope than "gym seat
licensing" itself (`organization_members`' role matrix is still explicitly unresolved
per §14, and Plan.md's own `lib/` layout has no org-admin feature folder at all).
Flagged as a known gap, not a silent omission — same "design it yourself" situation
Milestone 6 was in for messaging, scoped down the same way `_TemplateBrowser` was in
Milestone 4.5.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 68 tests passing (6 new: `Subscription.fromMap` ×2,
      `Invite.fromMap` ×4, plus the prior 62)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/`, including
      the new `coaching-api` route
- [x] `subscriptions`/`invites` schema + RLS, per §10.1-10.2, with an owner_id
      cross-table validation trigger (closing the gap §10.1 flags rather than leaving
      it purely app-layer)
- [x] `redeem_invite()` RPC + `coaching-api` route, validating invite status/expiry/
      uses, subscription status/seat capacity, and the resolved trainer before
      writing anything
- [x] `coaching_relationships` created with the right `type`/`org_id` depending on
      `owner_type`, `invites.uses_count` and `subscriptions.seats_used` incremented in
      the same transaction
- [x] A rollback-wrapped dry-run of migrations 021-022 against the live linked
      project confirmed no SQL errors before handing off the real apply step
- [x] Trainer-side "Seats & invites" screen: plan picker, usage summary, invite
      list with copy/revoke
- [x] Client-side "Join with a code" screen
- [ ] Migrations 021-022 actually applied to the live Supabase project — **you** need
      to do this (see manual steps doc)
- [ ] `coaching-api` redeployed with the new route — **you** need to do this
- [ ] A live device/emulator run of the full loop (trainer buys a plan → creates an
      invite → client redeems it → `coaching_relationships` row appears, seat count
      increments, invite shows as used) — not yet run, no live project confirmed for
      this milestone's tables yet
- [ ] Concurrent-redemption race (two clients hitting the last seat at once) — the
      `for update` locks were reviewed by hand against migration 009's precedent, not
      exercised against a real simultaneous request
- [ ] Real payment integration — **not built this session**, see manual steps doc
- [ ] QR code generation/scanning — **not built this session**, see manual steps doc

## 3. Known Gaps / Deliberate Non-Scope

- **No payment gateway.** Subscriptions activate immediately on self-serve insert,
  no charge collected. Flagged on-screen in the plan picker itself, not just in this
  doc. `razorpay_flutter` is in Plan.md's dependency list but not added to
  `pubspec.yaml` yet.
- **No QR generation/scanning.** Text/code only. `qr_flutter`/`mobile_scanner` not
  added.
- **Gym (`owner_type = 'organization'`) subscriptions have no admin UI.** Schema/RLS/
  RPC fully support them; the Flutter screens only cover an independent trainer's own
  seats. See §1's scoping note.
- **A gym owner/admin who isn't personally a trainer can't issue invite codes.** See
  §0's design note — `invites.created_by` doubles as the resolved
  `coaching_relationships.trainer_id` for gym-mode redemptions, so invite creation
  requires a `trainer_profiles` row on top of org owner/admin status.
- **`seats_used` never decrements.** No coaching-relationship-ending flow exists yet
  anywhere in the app to hook a decrement into. A future "end/pause relationship"
  feature needs to also free the seat.
- **No pricing-ladder decision.** §10.4/§14's linear-vs-degressive question is still
  open; the three tiers shipped here are the doc's own linear example, plain row
  data, easy to change later.
- **Invite redemption isn't reachable from onboarding/signup**, only from an
  already-onboarded client's Profile screen. Per §0 decision 4.
- **No "seats full, notify the coach to upgrade" notification.** §10.3 mentions this
  as part of the reject-on-full-seats flow, but `notifications.type`'s check
  constraint (migration 019) is a fixed enum without a matching type, and this
  milestone didn't touch that already-shipped migration to add one (CLAUDE.md: don't
  edit an already-applied migration in place — and per Milestone 6's own manual
  steps, 019 may not even be live yet). The `SEATS_FULL` error is still returned to
  the client attempting redemption; the coach/org just isn't proactively notified.
  Flagged as a follow-up, not silently dropped.
- Wearables (M5/M5.5), the marketplace/payouts (Milestone 8), and full moderation
  tooling remain entirely out of scope, unchanged by this milestone.
