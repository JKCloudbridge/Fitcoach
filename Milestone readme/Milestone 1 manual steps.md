# Milestone 1 — Manual Steps Required From You

Assumes Milestone 0's manual steps (Supabase project created, migrations 001-004
applied, JWT hook enabled) are already done. Nothing in this milestone needs new
migrations — role selection writes into the existing `trainer_profiles`/
`client_profiles` tables from migration 002.

## 1. Google OAuth client IDs

Google Sign-In needs OAuth 2.0 client IDs from Google Cloud Console (a Firebase
project isn't required for this — Firebase itself isn't wired up until Milestone 6).

1. In [Google Cloud Console](https://console.cloud.google.com), pick or create the
   project you want FitCoach's OAuth consent screen under.
2. APIs & Services → OAuth consent screen — configure if not already done (External,
   app name, support email).
3. APIs & Services → Credentials → Create Credentials → OAuth client ID, three times:
   - **Web application** — no redirect URIs needed for this flow. Copy the Client ID
     into `GOOGLE_SERVER_CLIENT_ID`. This is the one `GoogleSignIn.instance.initialize()`
     uses as `serverClientId`, and it must be a **Web** client, not Android/iOS, or
     the native ID-token exchange will fail even though the button appears to work.
   - **iOS** — bundle ID must match `fitcoach_app/ios/Runner.xcodeproj`'s bundle
     identifier. Copy the Client ID into `GOOGLE_IOS_CLIENT_ID`.
   - **Android** — package name `com.fitcoach.fitcoach_app` (or your real
     applicationId if you've changed it from the Milestone 0 placeholder) plus your
     debug/release signing certificate's SHA-1 fingerprint
     (`cd fitcoach_app/android && ./gradlew signingReport` to get it). Nothing from
     this one goes in `.env` — Android matches it automatically by package name +
     SHA-1, but it must exist in the Cloud Console project or sign-in fails silently
     on Android.

## 2. Supabase Dashboard → Authentication → Providers → Google

Enable the Google provider and paste the **Web** client ID from step 1 into its
"Client IDs" field (Supabase's `signInWithIdToken` verifies the token's audience
against whatever's configured here — this is a separate step from creating the
OAuth client itself, easy to miss).

## 3. Supabase Dashboard → Project Settings → Authentication → SMTP Settings — custom SMTP via Resend

**Added after the first live-device test** (Email OTP failed there, but only
because `.env` still had placeholder Supabase credentials — the Google button's
click actually reached the network and surfaced the real underlying problem this
step fixes). Supabase's built-in email sender is rate-limited to a handful of
emails per hour and sends from a shared Supabase domain that's often flagged as
spam — fine for a first manual smoke test, not workable for real development or
production. Proximity's project uses [Resend](https://resend.com) as its
Authentication custom SMTP provider instead; FitCoach follows the same setup:

1. Create a Resend account and, under **Domains**, add and verify the domain
   you'll send from (DNS records — SPF/DKIM — Resend gives you to add at your
   registrar). Until a domain is verified, Resend's own sandbox address works
   for testing but only delivers to your own verified account email.
2. **API Keys** → create a new key with **Sending access** — copy it, it's only
   shown once.
3. Supabase Dashboard → your project → **Project Settings → Authentication →
   SMTP Settings** → enable **Custom SMTP** and fill in:
   - **Sender email**: an address on your verified domain (e.g.
     `noreply@yourdomain.com`) — must match the domain verified in step 1, not
     a free-mail address
   - **Sender name**: `FitCoach`
   - **Host**: `smtp.resend.com`
   - **Port**: `465`
   - **Username**: `resend` (literally the string "resend", not your email)
   - **Password**: the API key from step 2
4. Save, then re-trigger the Email OTP "Send sign-in code" flow from the app —
   the code should now arrive from your own domain, not Supabase's shared sender.

This also raises the effective rate limit well past what's needed for manual
testing across this and later milestones (Milestone 7's invite emails, Milestone
8's payment receipts, etc. will all ride this same SMTP config once those
milestones exist).

## 4. Supabase Dashboard → Authentication → Email Templates → Magic Link

**Important, easy to miss**: Supabase's default "Magic Link" template only shows a
clickable link (`{{ .ConfirmationURL }}`), not a 6-digit code. Since FitCoach's
Email OTP screen expects the user to type a code, edit this template to also include
`{{ .Token }}` somewhere in the email body (e.g. "Or enter this code in the app:
`{{ .Token }}`"). Without this, `signInWithOtp` still works, but the user has no
code to type — the email link isn't handled by this flow, so they'd be stuck.

## 5. Fill `.env`

`GOOGLE_IOS_CLIENT_ID` and `GOOGLE_SERVER_CLIENT_ID` (from step 1) — Milestone 0's
manual steps said these could stay blank until now. Also confirm `SUPABASE_URL` and
`SUPABASE_ANON_KEY` are your real project's values, not the `.env.example`
placeholders — the "Failed host lookup: your-project-ref.supabase.co" error on a
live device run means they're still placeholders.

## 6. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```
(No `build_runner` re-run needed unless `.env` changed shape — no new `@Envied`
fields were added this milestone.)

## 7. What still needs a live project + real credentials to actually verify

- Google Sign-In actually returning a session (needs steps 1-2 done for real)
- Email OTP actually delivering a working, readable code (needs steps 3-4 done —
  without step 3, Supabase's shared sender may also just get silently
  rate-limited or spam-filtered even with step 4's template fix in place)
- Role selection actually inserting a row and the JWT hook + `resolveRole()` agreeing
  on the result
- The full loop end-to-end: sign in → role-select → land in the correct shell →
  edit profile → sign out → land back on `/login`
