# M5 Planning — Wearables & Fitness App Sync (deferred)

**Status:** Not started. M5 (wearables) and M5.5 (third-party fitness app sync) are
both **deferred** — the team decided on 2026-09-24 to skip straight to M6
(Messaging & notifications) and come back to this later. This doc exists so the
scope, sequencing, and open decisions aren't lost in the meantime. Nothing in this
doc has been built; no migrations, functions, or UI changes exist for it yet.

## Why deferred

- Genuinely new ground for the project — Plan.md itself flags wearables as having
  no sibling-app precedent, unlike most other milestones.
- Needs registered developer apps/credentials (Fitbit, Garmin, Whoop, Strava) the
  team doesn't have on hand yet.
- Needs a resolved credential-storage decision (Supabase Vault vs. external
  secrets manager) — still open per Plan.md §14.
- Needs real device-testing time (HealthKit on iOS, Health Connect on Android) —
  can't be meaningfully verified by `flutter test`/an emulator alone.
- None of it blocks M6 (messaging/notifications is a fully independent domain —
  no schema or Edge Function dependency on wearables).

## Combined future scope

| Sprint | Scope | Notes |
|---|---|---|
| M5 | Device-native wearables: `wearable_connections`/`wearable_metrics`, `health` package (HealthKit/Health Connect), `sync-wearable-data` Edge Function, wearable-driven habit auto-completion (§9.4) | Doc §3.12-3.13, §6.6, §9.4 |
| M5.5 | Third-party fitness **app** sync: Strava, Apple Fitness, and similar — added on top of M5's schema | Decided 2026-09-24, not in original Plan.md roadmap — see [[project_sprint_5_5_fitness_app_sync]] memory |

Apple Fitness is a special case worth flagging when M5.5 is scoped: on iOS, Apple
Fitness workout data is typically already exposed through HealthKit rather than a
separate OAuth API, so it may fall out of M5's HealthKit integration for free
rather than needing its own connector like Strava does. Worth re-checking Apple's
current API surface at that time rather than assuming a separate OAuth flow is
needed.

## Proposed phased approach (when resumed)

**Phase A — Schema only (low risk, can be done anytime, even ahead of the rest):**
- New migration(s): `wearable_connections` (source enum: healthkit | health_connect
  | fitbit | garmin | whoop | strava | apple_fitness — extend as M5.5 needs),
  `wearable_metrics` (unique `(client_id, metric_date, source)`).
- RLS: `client_id = auth.uid()` only on both tables — never exposed to trainers
  directly, not even read-only (doc line 268). Trainers only ever see an
  aggregated view via `trainer-client-dashboard` (§6.6).
- Data API grants per [[project_supabase_data_api_grants]] memory.
- `credential_reference` stays a pointer-only column — app code never reads a raw
  token from this table regardless of which secrets backend is chosen later.

**Phase B — M5 device-native sync:**
- Add `health` package to `fitcoach_app/pubspec.yaml` (verify current version live
  against pub.dev before pinning, per standing project rule).
- New `wearable-api` Edge Function (`fitcoach_backend/supabase/functions/wearable-api/`),
  reusing `_shared/auth.ts`/`_shared/errors.ts`/`_shared/supabaseAdmin.ts` unchanged.
- `sync-wearable-data` route: resolve `credential_reference`, pull from
  HealthKit/Health Connect, upsert `wearable_metrics`.
- Wire up habit auto-completion (§9.4): after upserting a day's metrics, check
  every active habit with a non-null `wearable_metric_field` against that row and
  write a `habit_logs` entry with `source = 'wearable_auto'` — this is what
  activates the `wearable_auto` values left schema-ready-but-unwired since
  migrations 015/016.
- Client Profile screen: real connect/disconnect toggles for HealthKit/Health
  Connect (`screenClientProfile()` in the concept file).
- Today/Progress screens: decide whether/how to reintroduce the steps/resting-HR
  (Today) and avg-steps/sleep (Progress) rows both milestones have deliberately
  left out until now.

**Phase C — M5.5 third-party app sync:**
- Per-service OAuth app registration (Strava first — most likely to have public
  dev docs and no gym-hardware dependency; Fitbit/Garmin/Whoop/Apple Fitness as
  needed).
- Extend `wearable_connections.source` enum and `wearable-api` routes per service.
- Token refresh handling is a new concern here that device-native HealthKit/Health
  Connect doesn't have (those don't expire the same way) — budget real design time
  for it, don't bolt it on ad hoc per provider.

## Open decisions to resolve before either sprint starts

Carried over from the original M5 scoping conversation — still unresolved:

1. Which wearables/services are actually in scope for launch vs. "nice to have
   later" — HealthKit + Health Connect are the safe MVP subset (no external OAuth
   needed); Fitbit/Garmin/Whoop/Strava/Apple Fitness each add real integration
   work and their own developer-account setup.
2. Credential storage: Supabase Vault vs. an external secrets manager (Plan.md
   §14, still open).
3. Scheduled Cron (every 4h, per doc §6.6) vs. on-demand-only sync triggered from
   the app — same "don't over-build a scheduled job" judgment call M3 and M4 both
   made for simpler counters/streaks.
4. Whether `trainer-client-dashboard` (§6.6, aggregated wearable summary) ships
   alongside this work or stays its own separate milestone.
5. Physical iOS/Android device availability for real HealthKit/Health Connect
   testing — flag loudly if unavailable when this sprint starts; automated tests
   alone can't verify real sensor data end-to-end.

## Prereqs checklist (gather before starting M5)

- [ ] Decision on Vault vs. external secrets manager for `credential_reference`
- [ ] Confirmation of which wearables/apps are in scope for the first pass
- [ ] Physical device(s) with real HealthKit/Health Connect data available
- [ ] Developer app registrations for any OAuth-based service in scope (Fitbit/
      Garmin/Whoop/Strava) — client ID/secret, redirect URIs
- [ ] Decision on Cron vs. on-demand sync
