# Milestone 6 — Manual Steps Required From You

This depends on migrations 007-017 already being live — you were applying those in
parallel with this session's build. Confirm they're done (`Milestone 4.5 manual
steps.md` covers 007-017) before running 018-020 below; 018's `start_conversation()`
reads `coaching_relationships` (migration 005) and 020's new policy also references
it, 019's `card_flagged` trigger reads `card_reports`/`workout_cards` (012/006), and
019's `card_assigned`/`client_completed_workout` triggers attach directly to
`workout_assignments` (007) — all of those need to already exist.

## 1. Apply migrations 018-020 (in order)

```
cd fitcoach_backend
supabase db query -f "../migrations/018_create_messaging.sql" --linked
supabase db query -f "../migrations/019_create_notifications.sql" --linked
supabase db query -f "../migrations/020_client_profiles_trainer_read.sql" --linked
```

018 and 019 each end with `alter publication supabase_realtime add table ...` —
this is the first time this project has needed Postgres Changes streaming. If your
project's `supabase_realtime` publication was ever manually narrowed (e.g. via the
dashboard's Database → Replication UI) rather than left at its default, double
check `messages` and `notifications` actually show as added:

```sql
select tablename from pg_publication_tables where pubname = 'supabase_realtime';
```

020 is a pure bug fix (see Milestone 6.md §1) — it only adds a new policy, it
doesn't touch or depend on anything from 018/019, so it's safe to run independently
of those two if you want to verify the "Unnamed client" fix in `assign_card_sheet`
before messaging is otherwise live.

## 2. Deploy the new `coaching-api` Edge Function

```
cd fitcoach_backend
supabase functions deploy coaching-api
```

First deploy of this function — no existing routes to preserve. No new secrets
needed (same auto-injected `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` every other
function uses). `workout-api` and `habits-api` are unchanged this milestone, no
redeploy needed for either.

## 3. Confirm `fitcoach_app/.env`

`EDGE_FUNCTIONS_BASE_URL` already covers `coaching-api` — same root Functions URL
every domain function shares. No `.env` changes, no `build_runner` re-run needed.

## 4. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```

## 5. Create test data and verify the messaging loop

You need at least one active `coaching_relationships` row between a trainer and
client test account — `Milestone 2 manual steps.md` covers creating one by hand if
you don't already have one from testing earlier milestones.

- As the trainer: open the Messages tab → tap the new-message icon → your test
  client should appear in the picker (this also exercises migration 020's RLS fix —
  if the client's real name shows instead of a blank/fallback, that fix is working)
  → start a conversation → send a message.
- As the client: open the Coach tab → the trainer's conversation should now be
  listed with an unread indicator → open it → the message should already be there
  (confirms `messages_select` RLS) → reply.
- Back on the trainer's device/session: the reply should appear **without a manual
  refresh** if the `conversation-{id}` Realtime channel and the publication add
  from step 1 are both working. If it only shows up after a pull-to-refresh, check
  the `pg_publication_tables` query above first.
- Tap the bell on either side: the other party's message should show as an unread
  `message`-type notification; opening the conversation from there should mark it
  read and clear the badge.

## 6. Verify the three non-message notification hooks

Each of these already has an existing flow from an earlier milestone — this
milestone only adds a trigger on top of it, so re-run the existing flow and check
the bell rather than looking for new UI:

- **`card_assigned`**: trainer assigns a workout card to a client (Milestone 2's
  flow) → the client should get a notification.
- **`client_completed_workout`**: mark a `workout_assignments` row's `status` to
  `'completed'` (there's no UI button for this yet — either do it via a raw REST
  `PATCH` as the client/trainer, or via the SQL editor for a quick check) → the
  assignment's trainer should get a notification.
- **`card_flagged`**: file a card report (Milestone 3's report flow, if built into
  the UI — otherwise a raw `POST /rest/v1/card_reports` as a signed-in user) → the
  card's trainer should get a notification.

## 7. FCM push — not built this session, needs a real decision first

No Firebase project, no `google-services.json`/`GoogleService-Info.plist`, and
`firebase_core`/`firebase_messaging`/`firebase_crashlytics` aren't in
`pubspec.yaml` yet even though Plan.md's dependency list and `main.dart`'s own
comment both anticipated adding them at this milestone. Same situation Milestone 5
hit with wearable OAuth credentials — flagging rather than guessing. When you're
ready to pick this up:

- [ ] Create a Firebase project, register the Android/iOS apps, download
      `google-services.json` / `GoogleService-Info.plist`
- [ ] Add `firebase_core`, `firebase_messaging`, `firebase_crashlytics` to
      `pubspec.yaml` (verify current versions live against pub.dev first, per the
      project's standing rule)
- [ ] Wire FCM token registration into `main.dart`'s already-flagged init spot,
      storing the token somewhere reachable by a future notify-on-insert hook
      (the four triggers in migration 019 would need a matching "also call the FCM
      HTTP v1 API" step, likely via a `pg_net`/Edge Function call from each trigger
      or a separate polling job — not designed yet, since it depends on the token
      storage decision above)
- [ ] Until then, the in-app bell built this milestone is the complete
      notification experience — no push, no lock-screen/background notifications

## 8. What still needs a live project + the steps above to actually verify

- The `is_conversation_member()` definer function and both RLS policies that use
  it — reviewed by hand for the "infinite recursion in policy" trap, not run
  against a real second account probing another user's conversation.
- `start_conversation()`'s two `raise exception` branches
  (`CANNOT_MESSAGE_SELF`, `NO_ACTIVE_RELATIONSHIP`) and its find-or-existing-1:1
  lookup — only reviewed by hand and `deno check`/`flutter analyze`/`flutter test`
  so far, same untested-against-a-real-token caveat every prior Edge Function's
  manual steps have flagged.
- Whether `messages`' `grant update (read_at)` column-level grant actually blocks a
  malicious `PATCH` attempting to also set `body` in the same request (should
  either strip the column or reject the whole request — worth a raw REST probe,
  not just a UI test where the app never sends that field).
- Migration 020's new policy against a second trainer account — confirm a trainer
  can read a client's `display_name` when they have an active relationship, and
  still cannot when they don't (e.g. an ended relationship, or someone else's
  client entirely).
