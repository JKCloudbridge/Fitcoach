# Milestone 6 — Messaging & notifications

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`, `deno check`) without confirming any of it
against a live Supabase project. It needs the manual steps in
`Milestone 6 manual steps.md` — including applying migrations 018-020, and the
018-020 migrations depend on 007-017 already being live (in progress as of this
session — see that doc).

Builds `conversations`/`conversation_members`/`messages` (Requirement 1 §3.17-3.19),
`notifications` (§3.20), the Messaging API (§6.7), and the `conversation-{id}`
Realtime channel (§6.8) — trainer↔client 1:1 direct messaging plus an in-app
notification bell. Branched fresh as `M6` off `main`'s tip (post-M4.5 merge), not off
the empty `M5` branch — per `M5 Planning.md`, wearables/M5/M5.5 are deferred and this
milestone has no dependency on them.

## 0. Scope decisions made this session

Four questions were flagged before writing any code (see the task's own framing);
resolved as follows, since the person asking was mid-migration-apply when this
session ran and asked to keep going rather than pause on each one:

1. **FCM push**: confirmed **not set up** — no `firebase_core`/`firebase_messaging`
   in `pubspec.yaml`, no `google-services.json`/`GoogleService-Info.plist` anywhere
   in the repo, `main.dart` still has its Milestone-6-deferred Firebase-init comment
   unactioned. Same treatment as Milestone 5's OAuth-credential gap: build the
   in-app bell fully (schema + Realtime + UI), flag FCM as a follow-up needing a
   Firebase project in the manual steps doc, don't guess at credentials that don't
   exist.
2. **`assignment-{client_id}` Realtime channel** (§6.8, trainer watching a client's
   live logging): **stays deferred**. It's listed in the doc's §6.8 table but not in
   Plan.md's own Milestone 6 scope row — only `conversation-{id}` chat is. Not
   built.
3. **1:1 vs. group conversations**: schema (`conversation_members` as a join table)
   stays generic — nothing here would need to change if group chat were added
   later — but the UI and `start_conversation()` RPC are **1:1 only** this
   milestone. The concept HTML never shows more than a single named DM thread per
   role either way, so there was no UI precedent asking for more.
4. **Who can message whom**: gated to an **active `coaching_relationships` row**
   between the two users (checked in either trainer/client direction). The doc's
   §4 RLS pattern for messaging doesn't say this explicitly, but every other
   cross-user write in this codebase (`assign_workout_card`, `assign_habit_template`)
   already uses exactly this gate, so it was the consistent default rather than an
   open-ended "anyone can message anyone."

One more design call, not in the original open-decisions list: **starting** a
conversation can't be plain RLS. Requirement 1 §4's own pattern for messages/
conversation_members — "readable/writable only where auth.uid() has a row in
conversation_members for that conversation_id" — is circular for the very first
membership row of a brand-new conversation, and creating one needs real validation
(an active coaching relationship) anyway. That's CLAUDE.md's "transactional write
RLS can't gate on its own" case, so `start_conversation()` is a security-definer RPC
behind a **new `coaching-api` Edge Function** (this function didn't exist yet —
first route in it), mirroring migration 009's `assign_workout_card()` shape exactly.
Sending/reading messages within an already-started conversation stayed plain
PostgREST per §6.7, as the task expected.

## 1. What Was Built

**Schema** (`migrations/018-020`):

- `018_create_messaging.sql` — `conversations`, `conversation_members`, `messages`.
  RLS via a `security definer` `is_conversation_member()` helper (a direct self-join
  inside `conversation_members`' own policy hits Postgres' "infinite recursion
  detected in policy" — routing the membership check through a definer function is
  the standard way around that). No direct `authenticated` INSERT grant on
  `conversations`/`conversation_members` at all — both are `start_conversation()`
  RPC-only, same lock-down shape as `workout_assignments`. `messages` UPDATE is
  narrowed to the `read_at` column only via a column-level grant, so marking a
  message read can never rewrite `body`/`sender_id`. Also adds `messages` to the
  `supabase_realtime` publication — this project's first table that needs
  Postgres Changes streaming.
- `019_create_notifications.sql` — `notifications` table (`user_id = auth.uid()`
  only, no direct `authenticated` INSERT — always system-written), plus four
  `security definer` trigger functions, each hooked onto an existing table rather
  than editing any previously-shipped migration/RPC in place:
  - `card_assigned` — `AFTER INSERT` on `workout_assignments` where
    `source = 'trainer_assigned'`. This is migration 009's own deferred "notifies
    client" TODO, closed out here.
  - `client_completed_workout` — `AFTER UPDATE` on `workout_assignments` when
    `status` transitions to `'completed'`. The coarsest signal the current schema
    actually has for "a client finished this plan" — there's no whole-session-done
    event at the per-set `workout_logs` granularity, and firing one notification
    per logged set would be noise, not signal.
  - `card_flagged` — `AFTER INSERT` on `card_reports` (migration 012), notifying
    the card's trainer.
  - `message` — `AFTER INSERT` on `messages`, notifying every other conversation
    member.
  Also adds `notifications` to `supabase_realtime`.
- `020_client_profiles_trainer_read.sql` — **a pre-existing gap fix, not new
  scope.** Migration 003's own header comment promises "trainer-side read access to
  their clients' profiles is added in Milestone 2 alongside
  coaching_relationships" — migration 005 never actually added it, so every
  trainer-side embedded `client_profiles(display_name)` select (e.g.
  `coaching_relationships_repository.dart`'s `fetchActiveClients`, used by
  `assign_card_sheet.dart`) has been silently returning `null`, and
  `assign_card_sheet`'s "Unnamed client" fallback has been firing unconditionally
  since Milestone 2. Surfaced because the conversation list needs a trainer to
  read a real client name, not a fallback string. Fixed as a new additive policy
  (Postgres OR's multiple SELECT policies together), not an edit to migration 003
  — that migration may already be live, and CLAUDE.md says don't edit an
  already-applied migration in place.

**Backend** (`fitcoach_backend/supabase/functions/coaching-api/`, new):

- One route, `POST /coaching-api/start-conversation`, open to either role (a
  trainer messaging a client and a client messaging a trainer are the same
  operation from `start_conversation()`'s point of view — it checks the
  relationship in both directions). Same `zValidator`/`mapRpcError` shape as
  `workout-api`, reusing `_shared/auth.ts`/`_shared/errors.ts`/
  `_shared/supabaseAdmin.ts` unchanged. `deno check` clean alongside `workout-api`
  and `habits-api`.

**Flutter app**, new `lib/features/messaging/` and `lib/features/notifications/`:

- `messaging/data/message_models.dart` — `Message`, `ConversationSummary`.
- `messaging/data/messaging_repository.dart` — direct-RLS `fetchConversations`
  (composed client-side from three flat queries — conversation_members mine,
  conversation_members other-party, messages latest-per-conversation — rather than
  one aggregation query PostgREST can't cheaply express across three tables;
  reasonable at this app's expected conversation volume, same "don't over-build"
  call this project made for `_TemplateBrowser`'s flat list), `fetchMessages`,
  `sendMessage`, `markConversationRead`.
- `messaging/data/start_conversation_repository.dart` — the one Dio call, mirrors
  `assign_workout_card_repository.dart`.
- `messaging/presentation/messaging_providers.dart` — `conversationsProvider`
  (`FutureProvider`) and `conversationMessagesProvider` (`StreamProvider.family`,
  this project's first Realtime consumer: initial fetch + `conversation-{id}`
  channel appending new inserts as they arrive).
- `messaging/presentation/conversations_list_screen.dart` — one screen shared by
  both the client "Coach" tab and the trainer "Messages" tab (parameterized by
  title/basePath, since the data shape is identical for both roles). Designed
  fresh, following this app's existing list-screen convention
  (`AppBar` + `ListView.separated`, same shape as `cards_list_screen.dart`) rather
  than the concept HTML's markup, since — as the task itself noted — the concept
  only ever mocks up a single hardcoded thread per role, not a list screen.
- `messaging/presentation/conversation_thread_screen.dart` — live thread view,
  bubbles styled after the concept's `screenCoach()`/`screenTrainerMessages()`
  (own messages right-aligned on lime, the other party's left-aligned on the card
  surface) rebuilt as real widgets. Marks the conversation read on open.
- `messaging/presentation/start_conversation_sheet.dart` — "+ new message" picker,
  reusing `trainerActiveClientsProvider` (trainer side, already existed) and a new
  `fetchActiveTrainers` on `coaching_relationships_repository.dart` (client side,
  symmetric addition — a client can have more than one active trainer, per
  Plan.md's "three coaching relationships in one app").
- `notifications/data/notification_models.dart`, `notifications_repository.dart` —
  fetch/mark-read only, no insert path (see schema note above).
- `notifications/presentation/notifications_providers.dart` —
  `notificationsProvider` (this app's second Realtime consumer, a personal
  `notifications-{user_id}` channel — not one of §6.8's two named channels, but
  the same per-user-Postgres-Changes shape applied to the one other table this
  milestone needs it for); invalidates `conversationsProvider` when a `message`-
  type notification arrives, so the conversation list's preview/unread state
  doesn't need its own separate live channel.
- `notifications/presentation/notification_bell.dart` — `AppBar` action, badge
  count from unread notifications, pushes `/notifications`.
- `notifications/presentation/notifications_screen.dart` — full list, mark-one/
  mark-all read; tapping a `message` notification opens that conversation, every
  other type just marks read in place (see Known Gaps).

**Router** (`app_router.dart`) — `/client/coach` and `/trainer/messages` now build
`ConversationsListScreen` (were `ComingSoonScreen`), each with a nested
`:conversationId` route to `ConversationThreadScreen`. New `/notifications` route
outside both shells. `NotificationBell` added to the `AppBar` of `TodaySessionScreen`,
the trainer "Clients" `ComingSoonScreen` (now takes an optional `actions` param),
and both `ClientProfileScreen`/`TrainerProfileScreen` — a shell-level shared app bar
wasn't built for this (see Known Gaps), so the bell is dropped into each shell's
most-visited existing screens instead of restructuring every screen's `Scaffold`.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 62 tests passing (5 new: `Message.fromMap` ×2,
      `AppNotification.fromMap` ×3, plus the prior 57)
- [x] `deno check` — clean across `fitcoach_backend/supabase/functions/`, including
      the new `coaching-api`
- [x] `conversations`/`conversation_members`/`messages` schema + RLS, gated per
      §4's "own row in conversation_members" pattern via a definer-function helper
- [x] `start_conversation()` RPC + `coaching-api` route, gated on an active
      coaching_relationship in either direction
- [x] `notifications` schema + RLS, four trigger-based emitters
      (`card_assigned`/`client_completed_workout`/`card_flagged`/`message`)
- [x] `messages` and `notifications` added to the `supabase_realtime` publication
- [x] Conversation list + live thread screens for both client ("Coach") and
      trainer ("Messages") shells
- [x] In-app notification bell: unread badge, list, mark-one/mark-all read, live
      via Realtime
- [x] Pre-existing `client_profiles` trainer-read RLS gap fixed (additive policy,
      no edit to an already-shipped migration)
- [ ] Migrations 018-020 applied to a live Supabase project — **you** need to do
      this (see manual steps doc) — and they depend on 007-017 already being live
- [ ] `coaching-api` deployed — **you** need to do this
- [ ] `supabase_realtime` publication actually streaming both new tables against a
      live project — the `alter publication` statements in 018/019 are untested
      against a real Realtime connection
- [ ] A live device/emulator run of the full loop (trainer starts a conversation
      with a client → sends a message → client sees it arrive live → replies → both
      see read receipts implicitly via the bell's unread count clearing; a
      `card_assigned`/`card_flagged`/`client_completed_workout` notification
      actually appears after each of those existing flows) — not yet run, no live
      project confirmed for this milestone's tables yet
- [ ] FCM push — **not built this session**, see manual steps doc

## 3. Known Gaps / Deliberate Non-Scope

- **FCM push notifications are entirely unbuilt** — no Firebase project/
  credentials on hand this session (see §0.1). In-app bell + Realtime is the full
  notification experience for now; FCM is a clearly-flagged follow-up, not a
  silent omission.
- **`assignment-{client_id}` Realtime channel not built** — deferred per §0.2,
  stays available for whenever `trainer-client-dashboard` or a "live logging"
  feature actually gets scoped.
- **Group conversations are schema-ready, not UI-ready** — `conversation_members`
  supports more than two members per row shape, but `start_conversation()` and
  every screen assume exactly one other party. Extending to groups later is a
  UI/RPC change, not a schema migration.
- **No shell-level shared app bar** — the notification bell is added
  screen-by-screen to the most-visited existing `AppBar`s in each shell (Today,
  both Profiles, the trainer's Clients placeholder, both Messages/Coach screens)
  rather than restructuring `RoleShell` to own one persistent bar across every
  tab. A handful of secondary screens (Discover, Progress, My Cards, Build, both
  Edit-profile screens) don't show the bell — reachable indirectly via Profile
  first. Flagged as a gap to close if that turns out to matter in practice, not a
  correctness risk.
- **Notification tap only deep-links for `message` type** — `card_assigned`,
  `client_completed_workout`, and `card_flagged` notifications mark read on tap
  but don't navigate anywhere; there's no per-type detail screen decoupled from
  existing flows (Today, a future dashboard) to jump to yet.
- **Conversation list has no search/filter, no pagination** — flat list, same
  "don't over-build" call as `_TemplateBrowser`'s public-template browser
  (Milestone 4.5) at today's expected conversation volume.
- **`client_completed_workout` fires on `workout_assignments.status = 'completed'`,
  not a finer-grained "session" concept** — the schema has no whole-session-done
  event separate from the whole plan being marked completed; see §1's schema note.
- Wearables (M5/M5.5), gym seats, the marketplace, and full moderation tooling
  remain entirely out of scope, per `M5 Planning.md`/Plan.md, unchanged by this
  milestone.
