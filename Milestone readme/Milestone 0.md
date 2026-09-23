# Milestone 0 — Foundation

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`) without a live Supabase project. It needs
the manual steps in `Milestone 0 manual steps.md` before it runs end-to-end.

## 1. What Was Built

**Repo scaffold** — `fitcoach_app/` (Flutter, Android + iOS), `migrations/`,
`CLAUDE.md`, `Plan.md`, this `Milestone readme/` folder. No `fitcoach_backend/` yet —
deferred to Milestone 2, the first milestone that actually needs an Edge Function
(`assign-workout-card`); nothing before that does, per the hybrid RLS/Edge Function
split in `Plan.md`.

**Android config** (`fitcoach_app/android/`):
- `settings.gradle.kts`: AGP `9.0.1`, Kotlin `2.3.20` — identical to both sibling
  apps (same Flutter 3.44.5 SDK generated it)
- `app/build.gradle.kts`: `namespace`/`applicationId` = `com.fitcoach.fitcoach_app`,
  `compileSdk` pinned to `37` up front (Proximity only discovered this was required
  after adding `flutter_secure_storage`; pre-empted here instead of hitting the same
  Gradle failure later), JVM target 17

**Database** (`migrations/001-004`, numbered, applied by hand against Supabase):
- `organizations`, `organization_members` (per Requirement 1 §3.1-3.2)
- `trainer_profiles`, `client_profiles` (§3.3-3.4)
- RLS enabled on all four tables — `organization_members` follows the exact policy
  shape from Requirement 1 §4 (readable by same-org members, writable by
  owner/admin only); `trainer_profiles` is public-read (Discover needs it later);
  `client_profiles` is private to the owning user. Trainer read-access to their
  *clients'* profiles is deliberately not added yet — that needs an active
  `coaching_relationships` row, which is Milestone 2's table.
- `004` adds `custom_access_token_hook`, which sets `app_metadata.role` on every
  issued JWT to `'trainer'` / `'client'` / `null` based on which profile row exists
  for that user — must be enabled in the dashboard (see manual steps doc).

**Flutter** (`fitcoach_app/`, package `fitcoach_app`, applicationId
`com.fitcoach.fitcoach_app`):
- Dependency set per `Plan.md`'s Milestone 0 scope: Riverpod (no codegen — see the
  pubspec comment explaining why `riverpod_generator` was dropped after a real
  version conflict with `envied_generator`), GoRouter, Dio, Drift + `drift_flutter`,
  `flutter_secure_storage`, `envied`, `supabase_flutter`, `google_sign_in`,
  `sign_in_with_apple`, plus baseline UI packages (`google_fonts`,
  `cached_network_image`, `flutter_form_builder`). Auth-specific wiring
  (Google Sign-In init, Email OTP) is Milestone 1 — the packages are pinned now,
  not used yet.
- `core/config/env.dart` — envied config: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `EDGE_FUNCTIONS_BASE_URL` (root Edge Functions URL; each feature repo appends its
  own domain function's path once `fitcoach_backend` exists), `GOOGLE_IOS_CLIENT_ID`,
  `GOOGLE_SERVER_CLIENT_ID`
- `core/network/dio_client.dart` — JWT interceptor reading from
  `flutter_secure_storage`, bounded timeouts (copied from Proximity's, which hit a
  real hung-request bug without them)
- `core/cache/app_database.dart` + `local_cache.dart` — one generic
  key/payload/fetchedAt Drift table, proving the codegen pipeline (same pattern
  Proximity uses, adopted directly rather than reinvented)
- `core/router/app_router.dart` — single placeholder route for now; the real
  role-gated client/trainer shells land in Milestone 1
- `core/providers.dart` — root Riverpod providers (Supabase client, secure storage,
  Dio, Drift database, local cache)
- `main.dart` — `Supabase.initialize`, `ProviderScope`, `MaterialApp.router`. No
  Firebase/push/crash/Google Sign-In init yet — those are Milestone 1 and 6.

## 2. Acceptance Criteria

- [x] `flutter create` scaffold matches sibling apps' Gradle/Kotlin/compileSdk config
- [x] `flutter analyze` — no issues
- [x] `flutter test` — placeholder smoke test passes
- [x] `dart run build_runner build` succeeds (envied + Drift codegen both run clean)
- [ ] Migrations 001-004 actually applied against a live Supabase project — **you**
      need to create that project first (see manual steps doc)
- [ ] JWT role claim verified live — needs the dashboard hook step
- [ ] App actually launches on a device/emulator with a real Supabase connection —
      not yet run end-to-end; `.env` currently has placeholder values only

## 3. Known Gaps / Deliberate Non-Scope

- No auth flow yet — nothing calls `signInWith*` yet, so there's no way to actually
  get a session and exercise the RLS policies live. That's Milestone 1.
- `fitcoach_backend/` doesn't exist yet — no Edge Function is needed until
  Milestone 2's `assign-workout-card`.
- No live end-to-end run happened in this session (no Supabase project exists yet)
  — verification was `flutter analyze`, `flutter test`, and `build_runner` only,
  same disclosed gap both sibling apps' own Milestone 1 docs flag.
- `com.fitcoach.fitcoach_app` is a placeholder applicationId (Flutter's default
  `--org com.fitcoach` naming) — confirm the real brand/domain before any release
  signing config is set up.
