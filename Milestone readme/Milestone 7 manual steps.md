# Milestone 7 — Manual Steps Required From You

Migrations 021-022 only depend on `organizations`/`organization_members` (migration
001), `trainer_profiles`/`client_profiles` RLS (003), and `coaching_relationships`
(005) — all confirmed **already live** on the linked project (`czbiopkliwqtdrarmvdu`,
checked this session via `select tablename from pg_tables where schemaname='public'`).
This milestone does **not** depend on migrations 010-020 (habits/messaging/
notifications) being live — as of this session those are **not yet applied** (the live
project's tables stop at roughly migration 009: `workout_logs`,
`assignment_exercises`, `coaching_relationships`, no `habit_templates`/`conversations`/
`notifications` tables exist yet). If you've applied more since, that's fine — 021-022
don't care either way — but don't assume 018-020 are live just because 021-022 are.

Both new migrations were dry-run against the live project this session inside a
`BEGIN; ...; ROLLBACK;` wrapper (no changes committed) to catch SQL errors before you
run them for real — they executed cleanly.

## 1. Apply migrations 021-022 (in order)

```
cd fitcoach_backend
supabase db query -f "../migrations/021_create_subscriptions_and_invites.sql" --linked
supabase db query -f "../migrations/022_redeem_invite_function.sql" --linked
```

021 creates `subscriptions`/`invites` plus the `validate_subscription_owner()`
trigger and `generate_invite_code()` helper; 022 creates `redeem_invite()`. Neither
touches the `supabase_realtime` publication — this milestone doesn't need live
streaming for anything.

## 2. Redeploy `coaching-api`

```
cd fitcoach_backend
supabase functions deploy coaching-api
```

This is a **redeploy**, not a first deploy — `coaching-api` already exists from
Milestone 6 (`start-conversation`). This adds `redeem-invite` alongside it. No new
secrets needed. `workout-api` and `habits-api` are unchanged this milestone.

## 3. Confirm `fitcoach_app/.env`

`EDGE_FUNCTIONS_BASE_URL` already covers `coaching-api` — no `.env` changes, no
`build_runner` re-run needed.

## 4. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

(No new packages were added this milestone — `qr_flutter`/`mobile_scanner`/
`razorpay_flutter` are deliberately not in `pubspec.yaml` yet, see §7 below — so
`flutter pub get` should be a no-op unless something else changed.)

## 5. Verify the seat-licensing loop

You need at least one trainer test account with a `trainer_profiles` row.

- As the trainer: open Profile → "Seats & invites" → pick a plan (e.g. Starter, 50
  seats / ₹1000). This should activate immediately (no payment prompt — see
  Milestone 7.md §0.1) and show a usage card at 0/50 seats.
- Tap "New invite" → leave max uses/expiry blank → Create. A code should appear in the
  list (8 uppercase hex characters), status "Active", used 0.
- Copy the code (tap the copy icon next to it, or read it off-screen).
- As a **different** test account, signed in as a client: open Profile → "Join with a
  code" → paste/type the code → Redeem. You should get a "Connected!" snackbar.
- Back on the trainer's subscription screen (pull to refresh): the invite should now
  show "used 1", and the usage card should show 1/50 seats used.
- Confirm the new `coaching_relationships` row exists and has `type = 'private'`,
  `org_id = null` (since this subscription is trainer-owned, not a gym) — either via
  the SQL editor or by checking that the client now appears in the trainer's
  "Assign to" picker (Milestone 2's flow) / messaging picker (Milestone 6's flow).

## 6. Verify the failure-mode error messages

Each of these should surface as a readable message on the redeem screen, not a raw
500/stack trace:

- **Bad code**: enter a code that doesn't exist → "That invite code doesn't exist".
- **Revoked**: as the trainer, revoke an invite (tap "Revoke" in the list) → try
  redeeming that same code as a client → "This invite has been revoked".
- **Max uses reached**: create an invite with max uses = 1, redeem it once
  successfully, try redeeming the same code again with a second client account →
  "This invite has already reached its maximum number of uses".
- **Seats full**: create a subscription with a small seat_limit directly via the SQL
  editor (e.g. `seat_limit = 1`), redeem one invite against it, then try a second →
  "This coach/gym has no seats left...". (Awkward to trigger through the UI alone
  since the picker only offers 50+ seat tiers — SQL editor is the practical way to
  test this one.)
- **Already connected**: redeem the same still-valid code twice with the *same*
  client account → "You're already connected with this coach".

## 7. What's deliberately not built yet, and why

- **No payment gateway.** Choosing a plan in the picker activates the subscription
  immediately with no charge. When you're ready to wire up real billing:
  - [ ] Add `razorpay_flutter` to `pubspec.yaml` (verify current version live against
        pub.dev first, per the project's standing rule) — Plan.md already anticipated
        this dependency for gym-seat billing
  - [ ] Decide the actual payment flow (checkout on plan selection, webhook
        confirming before the `subscriptions` row is created or activated, etc.) —
        this milestone's `createSubscription` writes the row directly and
        synchronously, which would need to change
  - [ ] Resolve §10.4's still-open linear-vs-degressive pricing-ladder decision
        before real money is involved
- **No QR generation/scanning.** `qr_flutter`/`mobile_scanner` aren't in
  `pubspec.yaml`. The invite list only shows/copies the plain text code. Add both
  packages and a QR view/scanner screen when this becomes a priority — §10.2 lists
  QR as one of three acceptable sharing formats, not a hard requirement for v1.
- **No gym-admin UI.** `owner_type = 'organization'` subscriptions work end-to-end at
  the database layer (schema, RLS, `redeem_invite()`) but nothing in the Flutter app
  creates or manages one — there's no organization-admin screen anywhere in this app
  yet. Needs `organization_members`' role permission matrix resolved first (§14) and
  a real "Clients"/gym-roster screen (currently a `ComingSoonScreen` per Milestone
  6's router).
- **`seats_used` doesn't decrement.** There's no flow anywhere yet to end/pause a
  `coaching_relationships` row, so nothing exercises this, but be aware a future
  "remove client" feature needs to also free the seat — it won't happen
  automatically.
- **No "seats full" notification to the coach.** The client attempting redemption
  sees the error; the coach/org isn't proactively notified to upgrade. Would need a
  new `notifications.type` value, which means editing migration 019's check
  constraint (not yet live as of this session — see the header note above) or adding
  a new additive migration for it.
