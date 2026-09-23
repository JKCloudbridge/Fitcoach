# Milestone 1 — Auth & Roles

Status: **code complete, not yet deployed.** Everything below was built and verified
locally (`flutter analyze`, `flutter test`) without a live Supabase project or real
Google OAuth credentials. It needs the manual steps in
`Milestone 1 manual steps.md` before it runs end-to-end.

## 1. What Was Built

**Auth** (`fitcoach_app/lib/features/auth/`) — Google Sign-In + true passwordless
Email OTP, no password anywhere, matching this milestone's explicit scope. This
deliberately follows an older pattern than Proximity's *current* auth (Proximity
moved to password + signup-confirmation-OTP some sprints ago and retired
`signInWithOtp`) — Proximity's code conventions (hand-written Riverpod
`StateNotifier`, secure-storage JWT sync, router redirect shape, `waitUntilLoggedIn`,
inline error text, plain `TextEditingController` forms) are what's actually reused;
the literal OTP-sign-in API calls come from baker_ally's earlier implementation,
since that's the one that actually has this flow:
- `data/auth_repository.dart` — the only file touching `supabase_flutter` directly:
  `signInWithOtp`/`verifyOTP(type: OtpType.email)` for email OTP, `google_sign_in` v7's
  native `authenticate()` + `signInWithIdToken` for Google (not the browser-tab
  `signInWithOAuth` handoff), plus `resolveRole()` (see below).
- `presentation/auth_provider.dart` — `AuthNotifier extends StateNotifier<AuthSessionState>`
  (Riverpod 3.x, hand-written, `legacy.dart` import — no codegen, same as both
  sibling apps by Milestone 1). Subscribes to `onAuthStateChange`, syncs the JWT to
  secure storage, resolves `role`. `waitUntilLoggedIn()` is a bounded busy-poll every
  screen awaits after a successful sign-in before navigating, closing the same
  "notifier state hasn't caught up yet" race both sibling apps hit live.
- `presentation/login_screen.dart` + `presentation/email_otp_screen.dart` — Google
  button, email field + "send code", 6-digit code entry. Plain `TextEditingController`
  + local busy-flag + inline error text, no `flutter_form_builder` (confirmed a dead
  dependency in both sibling apps for this kind of screen — not used here either).

**Role resolution — deliberately NOT read from the JWT claim client-side.**
`custom_access_token_hook` (migration 004) stamps `app_metadata.role` on the JWT for
RLS/Edge Function checks, but its own comment says that claim is "only a convenience"
for the backend, not the app's source of truth. `AuthRepository.resolveRole()`
instead queries `trainer_profiles`/`client_profiles` directly for a row with
`id = auth.uid()` — simpler than decoding the JWT client-side, and avoids needing a
session refresh immediately after role-select inserts a profile row.

**Role selection at signup** (`fitcoach_app/lib/features/onboarding/`) — neither
sibling app has this (both are single-role apps; baker_ally provisions its profile
row server-side, Proximity doesn't have a role concept in its buyer shell at all),
so `role_select_screen.dart` is built fresh for FitCoach: two role cards (trainer /
client) + a name field, submitting a direct RLS-gated insert into
`trainer_profiles`/`client_profiles` (`id = auth.uid()`, allowed by migration 003's
write policy) via `features/profile/data/profile_repository.dart`, then
`authProvider.notifier.refreshRole()` before routing into the matching shell.

**Two role-gated GoRouter shells** (`fitcoach_app/lib/core/router/app_router.dart`) —
replaces Milestone 0's single placeholder route. Neither sibling app actually has a
role-gated *shell* to copy (Proximity's `StatefulShellRoute` is a single buyer-only
bottom nav; its organizer/rider split is plain pushed routes gated only by
"signed in", not role), so this is new, following Proximity's *conventions*:
- `redirect_logic.dart` — the redirect guard's decision logic pulled out as a pure,
  unit-tested function (`resolveRedirect`), so it's exercised in `flutter test`
  without mocking GoRouter or Supabase. Handles: not-loaded-yet (no-op),
  signed-out → `/login`, signed-in-no-role → `/onboarding/role-select`,
  signed-in-with-role → bounced off `/login`/role-select into their shell, and a
  defensive guard bouncing a client out of `/trainer/*` routes and vice versa (not
  reachable via the app's own UI, but a deep link could still hit the wrong shell).
- `app_router.dart` — wires that logic into GoRouter's `redirect`, plus a
  `_GoRouterRefreshStream` bridging `AuthNotifier`'s stream into GoRouter's
  `ChangeNotifier`-based `refreshListenable` (same bridge both sibling apps use).
  Two `StatefulShellRoute.indexedStack`s: `/client/{today,discover,progress,coach,profile}`
  and `/trainer/{clients,cards,build,messages,profile}`, per Plan.md's nav map.
  Every tab except Profile is `shared/widgets/coming_soon_screen.dart` — a reusable
  placeholder, since Discover/Progress/Coach/messaging/the trainer roster and card
  tools are explicitly out of scope until later milestones; this milestone proves the
  shells navigate, not that those features exist.

**Basic profile screens** (`fitcoach_app/lib/features/profile/`) — view/edit for
both roles, direct RLS-gated reads/writes (no Edge Function needed, per CLAUDE.md's
hybrid backend pattern):
- `data/profile_models.dart` — hand-written `TrainerProfile`/`ClientProfile` with
  `fromMap`, plus `parseCommaSeparated()` for the `text[]` fields
  (certifications/goals), shared by both edit screens.
- `data/profile_repository.dart` — fetch/update per role.
- `presentation/{trainer,client}_profile_screen.dart` — view, with a sign-out
  button and an Edit button.
- `presentation/{trainer,client}_profile_edit_screen.dart` — plain
  `Form`/`TextFormField`/`GlobalKey<FormState>`, matching baker_ally's
  `edit_profile_screen.dart` shape (also not `flutter_form_builder`). Trainer: name,
  bio, certifications (comma-separated). Client: name, date of birth (date picker),
  height/weight, goals (comma-separated).
- **Avatar upload deliberately not built.** `avatar_url` is displayed read-only
  (`CircleAvatar`) when present; no `image_picker`/Storage upload flow. Full photo
  upload is a meaningfully separate feature (platform permissions, the `avatars`
  bucket, compression) not covered by "basic profile screens" — flagged as
  deliberately deferred, not an oversight.

**`main.dart`** — added `GoogleSignIn.instance.initialize(serverClientId: ...)`
right after `Supabase.initialize`, matching Proximity's init order (v7's API
requires `initialize()` to complete before anything else touches
`GoogleSignIn.instance`). Wrapped in try/catch, unlike Proximity — FitCoach's
`.env` still has a placeholder Google client ID until the manual steps below are
done, and a bad ID during local dev should fail Google sign-in at tap time, not
crash app boot.

**Removed**: `shared/widgets/foundation_check_screen.dart` (Milestone 0's
placeholder root screen, now unreferenced).

**New dependency**: `intl: ^0.20.2` (date formatting on the client profile view
screen) — already in Plan.md's "reused as-is from proximity" dependency list, just
not needed until now.

## 2. Acceptance Criteria

- [x] `flutter analyze` — no issues
- [x] `flutter test` — 19 tests passing (redirect logic, `AuthSessionState.copyWith`,
      profile model parsing, Milestone 0's placeholder smoke test)
- [x] Google Sign-In wired end-to-end in code (native ID-token exchange, matching
      Proximity's v7 pattern)
- [x] Email OTP wired end-to-end in code (send code → verify code, matching
      baker_ally's passwordless flow)
- [x] Role selection creates the matching profile row and routes into the correct
      shell
- [x] Two role-gated GoRouter shells replace Milestone 0's single placeholder route
- [x] Basic profile view/edit screens for both roles
- [ ] Actually exercised against a live Supabase project + real Google OAuth
      credentials — **you** need to do the manual steps first (see manual steps doc)
- [ ] Full device/emulator run of sign-in → role-select → shell → profile edit →
      sign-out — not yet run end-to-end, no live project exists yet

## 3. Known Gaps / Deliberate Non-Scope

- Apple Sign-In (`sign_in_with_apple`, pinned since Milestone 0) is **not** wired up
  this milestone — the task scope named only "Google Sign-In + Email OTP." Deferred,
  not forgotten.
- Avatar upload (see above) — deferred, `avatar_url` is read-only.
- Discover, habits, wearables, messaging, seats, and the marketplace are all
  explicitly out of scope per this milestone's instructions — every non-Profile
  shell tab is a `ComingSoonScreen` placeholder, not a stub of real functionality.
- The "both trainer and client" dual-role case (Plan.md's "out of scope for v1"
  note) is unaddressed — `resolveRole()` returns `'trainer'` first if both rows
  somehow exist, matching migration 004's own tie-break, but nothing in this
  milestone lets a user actually end up with both rows.
- No live end-to-end run happened this session (no Supabase project, no real Google
  OAuth client exists yet) — same disclosed gap Milestone 0's own doc flagged, now
  carried forward one milestone.
