# Milestone 0 — Manual Steps Required From You

1. Create a Supabase project (or reuse an existing one) for FitCoach.
2. Run `migrations/001_*.sql` through `004_*.sql` in order against it:
   ```
   supabase link --project-ref <ref>
   supabase db query -f migrations/001_create_organizations.sql --linked
   supabase db query -f migrations/002_create_profiles.sql --linked
   supabase db query -f migrations/003_rls_foundation.sql --linked
   supabase db query -f migrations/004_custom_access_token_hook.sql --linked
   ```
3. Supabase Dashboard → Authentication → Hooks → "Customize Access Token (JWT)
   Claims" → select `public.custom_access_token_hook`.
4. Fill real values into `fitcoach_app/.env` (copy from `.env.example` if starting
   fresh): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `EDGE_FUNCTIONS_BASE_URL`. Google
   client IDs can stay blank until Milestone 1.
5. Android SDK is missing `cmdline-tools` and hasn't accepted licenses yet
   (`flutter doctor` flags both) — needed before `flutter run` will work even on a
   physical device (Gradle still needs the SDK to compile). Fix via Android
   Studio's SDK Manager, or `flutter doctor --android-licenses` from a terminal
   that can accept the interactive prompt.
6. `cd fitcoach_app && dart run build_runner build --delete-conflicting-outputs`
   (re-run after step 4 if `.env` changed) then plug in a device and run
   `flutter run`.
