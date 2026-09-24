# Milestone 8 — Manual Steps Required From You

As of this session, the live linked project (`czbiopkliwqtdrarmvdu`) still only has
tables through roughly migration 009 (`workout_logs`/`assignment_exercises`/
`coaching_relationships` — confirmed this session via
`select tablename from pg_tables where schemaname='public'`). **Migrations 010-022
are not live either** (no `habit_templates`, no messaging/notifications tables, no
`subscriptions`/`invites`) — those were left pending across Milestones 4-7's own
sessions. This milestone's new migrations (023-029) depend on 014 (`habit_templates`)
and 015 (`habits`) existing as schema, so **all of 010-029 need to be applied in
order**, not just 023-029 — this doc covers the full remaining chain.

Everything below was dry-run this session as one combined
`BEGIN; ...; ROLLBACK;` transaction (010 through 029 together, since 023-029 can't be
validated in isolation against a project that doesn't have 010-022's tables yet) — it
executed cleanly with no SQL errors, and the rollback left the live project
untouched. That confirms the chain is internally consistent; it does not mean any of
it has been applied for real yet.

## 1. Apply migrations 010-029 (in order)

```
cd fitcoach_backend
supabase db query -f "../migrations/010_create_card_stats.sql" --linked
supabase db query -f "../migrations/011_create_saved_cards.sql" --linked
supabase db query -f "../migrations/012_create_card_reports.sql" --linked
supabase db query -f "../migrations/013_follow_public_card_function.sql" --linked
supabase db query -f "../migrations/014_create_habit_templates.sql" --linked
supabase db query -f "../migrations/015_create_habits.sql" --linked
supabase db query -f "../migrations/016_create_habit_logs.sql" --linked
supabase db query -f "../migrations/017_assign_habit_template_function.sql" --linked
supabase db query -f "../migrations/018_create_messaging.sql" --linked
supabase db query -f "../migrations/019_create_notifications.sql" --linked
supabase db query -f "../migrations/020_client_profiles_trainer_read.sql" --linked
supabase db query -f "../migrations/021_create_subscriptions_and_invites.sql" --linked
supabase db query -f "../migrations/022_redeem_invite_function.sql" --linked
supabase db query -f "../migrations/023_create_programs_and_program_habits.sql" --linked
supabase db query -f "../migrations/024_create_program_subscriptions.sql" --linked
supabase db query -f "../migrations/025_create_payouts.sql" --linked
supabase db query -f "../migrations/026_add_program_subscription_id_columns.sql" --linked
supabase db query -f "../migrations/027_extend_paid_content_rls.sql" --linked
supabase db query -f "../migrations/028_subscribe_program_function.sql" --linked
supabase db query -f "../migrations/029_expire_program_subscriptions_function.sql" --linked
```

018/019 each end with `alter publication supabase_realtime add table ...` (see
`Milestone 6 manual steps.md` §1 if your `supabase_realtime` publication was ever
manually narrowed). Nothing in 023-029 touches Realtime.

If you've already applied some prefix of 010-022 in between sessions, that's fine —
each file is a plain sequential `CREATE`/`ALTER`, so just resume from wherever you
actually left off and skip what's already live. Double-check with:

```sql
select tablename from pg_tables where schemaname = 'public' order by tablename;
```

## 2. Deploy the new `programs-api` Edge Function

```
cd fitcoach_backend
supabase functions deploy programs-api
```

**First deploy of this function** — no existing routes to preserve, same situation
`coaching-api` was in at Milestone 6. No new secrets needed for the
`subscribe-program` route (same auto-injected `SUPABASE_URL`/
`SUPABASE_SERVICE_ROLE_KEY` every other function uses). `workout-api`, `coaching-api`,
and `habits-api` are unchanged this milestone — no redeploy needed for any of them.

## 3. Confirm `fitcoach_app/.env`

`EDGE_FUNCTIONS_BASE_URL` already covers `programs-api` — same root Functions URL
every domain function shares. No `.env` changes, no `build_runner` re-run needed.

## 4. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

(No new packages were added this milestone — `razorpay_flutter` is deliberately
still not in `pubspec.yaml`, see §6 below — so `flutter pub get` should be a no-op
unless something else changed.)

## 5. Verify the marketplace loop

You need one trainer test account with a `trainer_profiles` row, at least one
existing `workout_cards` row and one `habit_templates` row owned by that trainer
(from earlier milestones' test data, or build fresh ones from the trainer's Build
tab), and a separate client test account.

- As the trainer: Build tab → "Program" segment → fill in a title, set a price (e.g.
  ₹999), pick the workout card from the dropdown, check one or more habit templates,
  toggle Published on, Save.
- Trainer's "My Cards" tab → "Programs" segment: the new program should appear,
  showing the price and no "Draft" suffix.
- As the client: Discover → "Programs" segment: the program should appear with its
  price. Tap it — the detail sheet should show the bundled workout card title and
  habit titles, plus the on-screen "no payment gateway" notice.
- Tap Subscribe. You should get a "Subscribed — check My Programs" snackbar.
- Client Profile → "My Programs": the subscription should appear, status "Active",
  the price paid, and today's date.
- Confirm the client's Today screen now shows the bundled card's assignment (same
  place a trainer-assigned card would show up), and their habit list shows the
  bundled habit(s) — either via the SQL editor
  (`select * from workout_assignments where program_subscription_id is not null`,
  same for `habits`) or by checking the UI directly.
- Re-open Discover's Programs list — the subscribed program should now show a
  "Subscribed" tag instead of the chevron.

## 6. Verify paid-content RLS gating (§11.7)

- Using the SQL editor (or a second client account with no subscription), confirm a
  **non-subscribed** client cannot read the bundled workout card's `exercises` rows
  or the bundled `habit_templates` row's detail fields directly via PostgREST, even
  though the `programs`/`workout_cards` listing itself stays visible. This is the
  behavior migration 027 is supposed to produce — worth confirming once, since it's
  a policy swap on top of already-live tables (006/014), not a fresh table.
- Confirm the **subscribing** client (from step 5) *can* read those same rows once
  subscribed.
- Confirm the **owning trainer** can always read their own card/template's
  exercises/detail regardless of any of this.

## 7. Verify `expire-program-subscriptions` / `run-payouts` on demand

Both routes require the **service-role key** as the bearer token, not a normal user
JWT — calling them with a client/trainer's session token will get a 403
`FORBIDDEN`/"Service-role access only". From a terminal (replace
`<service-role-key>` and `<project-ref>`):

```
curl -X POST "https://<project-ref>.supabase.co/functions/v1/programs-api/expire-program-subscriptions" \
  -H "Authorization: Bearer <service-role-key>"

curl -X POST "https://<project-ref>.supabase.co/functions/v1/programs-api/run-payouts" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"periodStart":"2026-09-01","periodEnd":"2026-10-01"}'
```

`expire-program-subscriptions` should return `{"data":{"expiredCount":0}}` on a
project with nothing past its `current_period_end` yet (every `program_subscriptions`
row created via a `'one_time'` program has no period end to expire against; test the
`'monthly'` path by manually backdating a test row's `current_period_end` via the SQL
editor first). `run-payouts` should return created/held-below-threshold trainer ids
based on whatever `program_subscriptions` rows exist in that date range — check
`select * from payouts` afterward.

## 8. What's deliberately not built yet, and why

- **No payment gateway.** Subscribing to a program activates access immediately with
  no charge collected. When you're ready to wire up real billing:
  - [ ] Add `razorpay_flutter` to `pubspec.yaml` (verify current version live
        against pub.dev first, per the project's standing rule)
  - [ ] Decide the actual payment flow (checkout on Subscribe tap, then
        `program-payment-webhook` confirming before `program_subscriptions` is
        created/activated) — this milestone's `subscribe-program` route calls
        `subscribe_program()` directly and synchronously, which would need to change
  - [ ] Resolve whether `subscribe-program` itself should stay a thin "create
        checkout intent" endpoint once a real webhook exists, or whether the RPC call
        moves entirely into the webhook handler
- **No real payout money movement, anywhere.** This is not a "not yet" item in the
  usual sense — see Milestone 8.md §0 decision 2 and Requirement 1 §11.8. Before
  writing any code that moves real money:
  - [ ] Get the CA/fintech-consultant sign-off §11.8 explicitly calls for
  - [ ] Pick a payment aggregator built for split settlement (Razorpay Route,
        Cashfree Easy Split) — custom payout logic against a raw gateway is not
        compliant for splitting a client payment between the platform and a coach
  - [ ] Handle GST/TDS (Section 194-O) as part of that integration, not bolted on
        after
- **No cancel-subscription UI.** A client can subscribe but not un-subscribe. Add a
  cancel action to `MyProgramsScreen` (updating `program_subscriptions.status`, plus
  archiving the tagged assignments/habits — likely by extending
  `expire_program_subscriptions()` or adding a sibling RPC) when this becomes a
  priority.
- **Supabase Cron isn't configured for `expire-program-subscriptions`/
  `run-payouts`.** First scheduled-job attempt in this project. To wire it up once
  you're ready:
  - [ ] In the Supabase dashboard, enable the `pg_cron` and `pg_net` extensions
        (Database → Extensions) if not already on
  - [ ] Schedule a daily job calling `expire-program-subscriptions` and a monthly
        job calling `run-payouts` with the appropriate `periodStart`/`periodEnd`, each
        via `net.http_post` to this function's URL with the service-role key in the
        `Authorization` header — same shape as the `curl` calls in §7 above, issued by
        `pg_cron` instead of by hand. Supabase's own "Schedule Edge Functions with
        pg_cron" guide covers the exact `cron.schedule(...)` SQL for this.
  - [ ] Until this is done, both routes are still fully callable/testable on demand
        (§7) — this is a "code complete, needs a human to flip a dashboard switch"
        gap, same treatment FCM push got in Milestone 6.
- **`run-payouts`' below-threshold hold doesn't roll over for real.** See Milestone
  8.md's known gaps — a trainer under the ₹500 threshold in one run is simply
  skipped, not carried into the next period's aggregation. Not a concern while no
  real money moves, but flag it if this becomes load-bearing later.
