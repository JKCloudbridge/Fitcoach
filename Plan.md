# FitCoach — Foundation & Build Plan

## Context

FitCoach is a new gym/trainer-client coaching app: trainers build workout cards and
assign them to clients, clients log workouts daily, wearables feed step/HR/sleep data
in automatically, and there are two revenue tracks (gym seat licensing + a paid
Programs marketplace with trainer payouts). A detailed v3 data-model/API doc already
exists (`Initial requirement/Requirement 1`) covering schema, RLS policies, and Edge
Functions, plus a UI concept (`fitcoach-ui-concept.html`) showing a client app
(Maya) and a trainer app (Jordan).

Rather than starting from a blank Flutter template, this plan reuses the exact,
proven setup from two sibling apps already built the same way:

- **Chef & Baker** (`C:\Users\hemin\Desktop\Android Project`, repo name `baker_ally`)
- **Proximity** (`C:\Users\hemin\Desktop\Proximity`)

Both are **Flutter apps** (not native Kotlin/Java) targeting Android + iOS from one
codebase, backed by **Supabase** (Postgres/Auth/Storage/Realtime) with a **Deno/Hono
Edge Function** for backend logic. Both ship via numbered SQL migration files, a
`CLAUDE.md` repo map, an architecture doc, and milestone-by-milestone delivery with
a "manual steps" doc per milestone (things only the human can do: dashboard toggles,
credentials, deploys). Proximity is the more recent of the two (Sep 2026 vs Jul 2026)
and already solves FitCoach's exact "one app, two very different mobile roles"
problem via its `features/organizer/` and `features/rider/` folders — that's the
direct precedent for FitCoach's trainer vs. client split, so FitCoach will be **one
Flutter app**, not two, with role-gated navigation shells.

Confirmed decisions from this session:
1. **Stack**: Flutter + Supabase, matching both sibling apps (not native Android).
   An external architecture review shared mid-session used Next.js in its
   diagrams — that was illustrative of the backend/RLS/Hono split, not a
   frontend recommendation; it doesn't change the Flutter decision already
   confirmed above, since it's the same client-side pattern (direct
   Supabase queries for simple reads + calls to Hono-routed Edge Functions
   for transactional writes) regardless of which client framework is calling it.
2. **Backend access pattern**: **Hybrid**, per the v3 doc as already written —
   `supabase_flutter` direct reads gated by the RLS policies in §4 of the doc, and
   Hono-routed Supabase Edge Functions (`fitcoach_backend`) only for the
   transactional writes the doc already calls out in §6.6/§13 (assign-workout-card,
   redeem-invite, subscribe-program, etc.). This deliberately diverges from both
   sibling apps' "everything through one Hono function, service-role only" rule —
   flagged here so it's a visible, intentional choice, not a drift. See "Backend
   Setup" below for how the Edge Functions themselves are organized (also revised
   this session per the same external review: several small domain-grouped
   functions, each internally routed with Hono, rather than one monolithic function).

## Repo Layout (mirrors baker_ally / proximity)

```
FitCoach/
├── CLAUDE.md                      — repo map (see baker_ally's, §"How to write it" below)
├── Plan.md                        — full architecture reference (this doc's expanded successor)
├── Planning docs/
│   └── Architecture/
│       └── 00_common_architecture.md   — FitCoach's own version of baker_ally's file:
│                                          nav map, Riverpod provider tree, role/RLS
│                                          model, decisions log — written before Milestone 1
├── Initial requirement/           — already exists, kept as-is (source of truth for schema)
├── migrations/                    — plain numbered .sql files, applied by hand via
│                                     `supabase db query -f migrations/0NN_name.sql --linked`
│                                     (no supabase/migrations dir, no `db push` — same as both siblings)
├── Milestone readme/              — one `Milestone N.md` + `Milestone N manual steps.md` per milestone
├── fitcoach_app/                  — Flutter app (Android + iOS)
└── fitcoach_backend/              — several domain-grouped Supabase Edge Functions, Hono, Deno (see "Backend Setup" below)
```

No separate admin web app for now — the doc's UI concept has trainers on mobile
(Jordan's screens), and there's no admin-panel requirement in the doc. Card
moderation (`moderate-card`) ships as an Edge Function only, callable from a
future thin admin surface if/when that's actually needed — tracked as an open
decision, not built speculatively.

## Flutter App Setup (`fitcoach_app/`)

**Package/applicationId**: `com.fitcoach.fitcoach_app` (Flutter's default
`--org com.fitcoach` naming, same pattern as `com.chefsandbakers.app` /
`com.proximity.proximity_app` — confirm real brand domain before release signing).

**`android/` config** — copy proximity's gradle setup verbatim (it's the newer,
already-debugged one):
- `settings.gradle.kts`: AGP `9.0.1`, Kotlin `2.3.20`, Flutter plugin loader
- `app/build.gradle.kts`: `compileSdk = 37` (proximity bumped this from
  `flutter.compileSdkVersion` because `flutter_secure_storage`'s own build
  requires it — same package will be in FitCoach's stack, so start at 37
  directly instead of hitting the same failure), `minSdk/targetSdk/versionCode`
  from `flutter.*`, JVM target 17
- No `coreLibraryDesugaring` unless `flutter_local_notifications` is added later
  (baker_ally needed it for that package specifically; proximity didn't need it)

**`pubspec.yaml` dependencies** — start from proximity's list (the more current
of the two) and add only what FitCoach specifically needs on top:

Reused as-is from proximity:
- State/DI: `flutter_riverpod`, navigation: `go_router`, networking: `dio`
- Storage: `flutter_secure_storage`, local cache: `drift` + `drift_flutter` + `path_provider`
- Auth/backend: `supabase_flutter`, `google_sign_in`, `sign_in_with_apple`
- Config: `envied` (+ `envied_generator` dev dep)
- UI: `google_fonts`, `cached_network_image`, `flutter_form_builder` + `form_builder_validators`, `image_picker`, `url_launcher`
- Push/crash: `firebase_core`, `firebase_messaging`, `firebase_crashlytics`
- Payments: `razorpay_flutter` (reused for both seat-subscription billing and program purchases)
- `intl`, `build_runner`, `riverpod_generator` (baker_ally had this; add since FitCoach needs generated providers for the workout/habit domain), `drift_dev`, `flutter_lints`

New for FitCoach specifically (verify each live against pub.dev before pinning —
this is a standing rule in both sibling apps' commit history, keep it):
- **`health`** — wraps HealthKit (iOS) + Health Connect (Android) for step/HR/sleep
  reads; needed for §9.4/§12 wearable sync. Neither sibling app has touched wearables,
  so this is genuinely new ground — budget real device-testing time here, not just
  a package add.
- **`fl_chart`** — progress charts (streaks, adherence %, weight/rep trends) for
  the client "Your progress" screen and trainer dashboard.
- **`qr_flutter`** (generate) + **`mobile_scanner`** (scan) — gym invite codes
  (§10.2/§10.3), QR variant.

**`lib/` structure** — same feature-first shape as both siblings:
```
lib/
├── core/
│   ├── config/         — envied env vars (SUPABASE_URL, SUPABASE_ANON_KEY, EDGE_FUNCTIONS_BASE_URL)
│   ├── network/         — dio_client.dart (JWT interceptor, timeouts — copy proximity's directly)
│   ├── router/          — app_router.dart — role-gated shells (see below)
│   ├── storage/          — secure_storage.dart
│   ├── cache/            — Drift AppDatabase
│   ├── push/              — FCM wiring
│   ├── crash/              — Crashlytics wiring
│   └── theme/
├── features/
│   ├── auth/               — Google + Email OTP, role selection (trainer/client) at signup
│   ├── onboarding/          — role-specific first-run (goals for client, certs for trainer)
│   ├── workout_cards/       — trainer: create/edit cards + exercises ("Build the session")
│   ├── assignments/         — client: active plan, "Today's session" (workout_assignments + assignment_exercises)
│   ├── workout_logs/        — set-logging UI, feeds Progress
│   ├── discover/            — public card browsing, saved_cards, follow-public-card
│   ├── progress/            — client progress charts (fl_chart), adherence
│   ├── habits/               — habit templates (trainer) + habit tracking (client)
│   ├── wearables/            — health package integration, connection management
│   ├── coach_roster/          — trainer: client list, trainer-client-dashboard view
│   ├── messaging/              — conversations/messages, Realtime channel
│   ├── notifications/           — bell + FCM
│   ├── gym_seats/                — subscriptions/invites (trainer/org side), redeem flow (client side)
│   ├── programs/                   — marketplace: browse, subscribe, trainer program builder
│   └── profile/                     — trainer_profiles / client_profiles editing
└── shared/
    ├── widgets/
    ├── errors/
    └── utils/
```

**Two role-gated shells in GoRouter** (direct analog of proximity's
organizer/rider split, driven off `organization_members.role` /
`trainer_profiles` vs `client_profiles` existing for the signed-in user):
```dart
StatefulShellRoute — Client shell: Today / Discover / Progress / Coach(messages) / Profile
StatefulShellRoute — Trainer shell: Clients / My Cards / Build / Messages / Profile
redirect: unauthenticated -> /login; authenticated but no profile row yet -> /onboarding/role-select
```
A user who is both (independent trainer who also trains) is out of scope for v1 —
the doc's schema allows one `auth.users` row to have both a `trainer_profiles`
and `client_profiles` row, but the UI concept only shows single-role sessions;
treat "which shell do I land in" as a simple stored preference/toggle if this
comes up, not a blocking decision now.

## Backend Setup (`fitcoach_backend/`)

Thin, on purpose — most reads bypass it entirely via RLS. Where both sibling
apps deploy **one** Hono Edge Function named `api` for literally everything,
FitCoach deliberately splits into **several small Edge Functions, each with its
own internal Hono app**, grouped by domain. This is a second intentional
deviation from the sibling-app pattern (the first being the hybrid RLS/Edge
Function split itself) — confirmed this session per external architecture
review: Supabase's own docs describe exactly this "Hono inside an Edge
Function, multiple endpoints per function" shape, and grouping by domain keeps
each function's cold-start/deploy blast radius small (a wearables bug doesn't
require redeploying the payments function) as the doc's own scope (§9-§11) is
considerably larger than either sibling app's backend.

```
fitcoach_backend/supabase/functions/
├── workout-api/            index.ts + Hono routes: workouts, exercises, assignments
│                            (assign-workout-card, follow-public-card land here)
├── coaching-api/            index.ts + Hono routes: clients, coaching_relationships, invites
│                            (redeem-invite lands here)
├── programs-api/             index.ts + Hono routes: programs, subscribe-program,
│                              program-payment-webhook, run-payouts
├── dashboard-api/              index.ts — trainer-client-dashboard aggregation
├── wearable-api/                 index.ts — connect + sync-wearable-data
├── habits-api/                     index.ts — habit CRUD + update-habit-streaks
├── moderation-api/                  index.ts — moderate-card (deferred until
│                                     moderation is actually needed, per open decisions)
├── notifications-api/                index.ts — weekly-progress-report, notification writes
└── _shared/                            auth.ts, permissions.ts, validation.ts, errors.ts
                                         (imported by every function above — same
                                         JWT-verification middleware shape as both
                                         siblings' authMiddleware, written once here)
```

Scheduled jobs (`sync-wearable-data`, `update-habit-streaks`,
`expire-program-subscriptions`, `update-card-stats`, `weekly-progress-report`,
`run-payouts`) live inside the domain function they belong to (e.g.
`run-payouts` inside `programs-api`) and are invoked via Supabase Cron hitting
that function's route — no separate jobs runtime needed.

`run-payouts` is the heaviest compliance risk in the whole plan (§11.8) — do
not build real money movement there without the CA/fintech-consultant sign-off
the doc itself flags. Build it last, and stub/mock it until that sign-off exists.

Flutter's `dio_client.dart` uses `EDGE_FUNCTIONS_BASE_URL` (the root
`.../functions/v1` URL) as Dio's `baseUrl`; each feature's repository appends
its own function's path (`workout-api`, `wearable-api`, ...) per-request,
rather than one shared flat API base URL.

## Milestone Roadmap

Mirrors both siblings' incremental-delivery practice (`Milestone N.md` +
`Milestone N manual steps.md` per milestone, status marked "code complete, not
yet deployed" until you've run the manual steps). Proposed order, each building
on the last, MVP-first:

| # | Milestone | Scope | Doc §§ |
|---|---|---|---|
| 0 | **Foundation** | Flutter project scaffold, Android/iOS platform config, Supabase project, base migrations (`organizations`, `organization_members`, `trainer_profiles`, `client_profiles`), custom JWT role-claim hook, folder skeleton | §2, §3.1-3.4 |
| 1 | **Auth & roles** | Google Sign-In + Email OTP (proven path from Milestone 1 of both siblings), role selection at signup, role-gated GoRouter shells, profile screens | §3.1-3.4, §4 (RLS foundation) |
| 2 | **Core coaching loop (the actual value prop)** | `workout_cards` + `exercises` (trainer), private `coaching_relationships`, `workout_assignments` + `assignment_exercises` snapshot pattern, `workout_logs`, trainer "Build the session" screen, client "Today's session" screen | §3.5-3.10, §6.2-6.4, §6.6 (`assign-workout-card`) |
| 3 | **Discover & self-directed** | Public card visibility, `saved_cards`, `follow-public-card`, `card_stats`, basic moderation flag (not full moderation UI) | §3.11, §3.15-3.16, §6.5 |
| 4 | **Progress & habits** | Progress charts (`fl_chart`), `habit_templates`/`habits`/`habit_logs`, streak computation | §9, Progress screens |
| 5 | **Wearables** | `health` package integration, `wearable_connections`/`wearable_metrics`, `sync-wearable-data` job, wearable-driven habit auto-completion | §3.12-3.13, §9.4 |
| 6 | **Messaging & notifications** | `conversations`/`messages` + Realtime, `notifications` table, FCM push, in-app bell | §3.17-3.20, §6.7-6.8 |
| 7 | **Gym seat licensing** | `subscriptions`, `invites`, `redeem-invite`, gym-mode `coaching_relationships`, seat-limit enforcement | §10 |
| 8 | **Marketplace & payouts** | `programs`, `program_habits`, `program_subscriptions`, Razorpay checkout, `payouts`, platform fee — **flag the RBI Payment Aggregator / GST-TDS compliance note (§11.8) before any real money moves** | §11 |

Milestones 0-2 are the critical path to a demoable app (trainer assigns a card,
client logs it, progress reflects it). 3-8 layer on top without touching the
core assignment/logging tables again — the snapshot pattern in §3.9 is
specifically designed so later milestones don't require schema churn in the
ones before them.

## Open Decisions Carried Forward (from doc §14, unresolved — not this plan's job to close)

- Video CDN at scale (Mux vs Cloudflare Stream vs raw Storage)
- `organization_members` role permission matrix (can an admin remove a trainer?)
- Wearable credential storage (Supabase Vault vs external secrets manager)
- Seat pricing ladder (linear vs degressive), marketplace platform fee %, payout cadence
- Payment aggregator + compliance setup for split payouts (needs a CA/fintech consultant)
- Whether a card moderation UI is ever needed, and where it lives if so

## Verification per Milestone

Same bar both siblings use before calling a milestone "code complete":
- `flutter analyze` + `flutter test` (Flutter side)
- `deno check` (Edge Functions)
- Manual steps doc lists every dashboard/credential/deploy step still needed
  before it runs end-to-end live — nothing is claimed "done" without a live
  Supabase project unless explicitly marked "code complete, not yet deployed"
- Milestone 2 in particular needs a real device/emulator run through the full
  loop (trainer builds card → assigns → client logs a set → progress updates)
  before being called done, not just unit tests
