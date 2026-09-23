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

## 3. Supabase Dashboard → Authentication → Email Templates → Magic Link

**Important, easy to miss**: Supabase's default "Magic Link" template only shows a
clickable link (`{{ .ConfirmationURL }}`), not a 6-digit code. Since FitCoach's
Email OTP screen expects the user to type a code, edit this template to also include
`{{ .Token }}` somewhere in the email body (e.g. "Or enter this code in the app:
`{{ .Token }}`"). Without this, `signInWithOtp` still works, but the user has no
code to type — the email link isn't handled by this flow, so they'd be stuck.

Email provider itself is enabled by default in a new Supabase project — no separate
toggle needed for OTP sign-in beyond this template edit.

## 4. Fill `.env`

`GOOGLE_IOS_CLIENT_ID` and `GOOGLE_SERVER_CLIENT_ID` (from step 1) — Milestone 0's
manual steps said these could stay blank until now.

## 5. Re-fetch dependencies and run

```
cd fitcoach_app
flutter pub get
flutter run
```
(No `build_runner` re-run needed unless `.env` changed shape — no new `@Envied`
fields were added this milestone.)

## 6. What still needs a live project + real credentials to actually verify

- Google Sign-In actually returning a session (needs steps 1-2 done for real)
- Email OTP actually delivering a working code (needs step 3 done, or the user is
  stuck with a link and no visible code)
- Role selection actually inserting a row and the JWT hook + `resolveRole()` agreeing
  on the result
- The full loop end-to-end: sign in → role-select → land in the correct shell →
  edit profile → sign out → land back on `/login`
