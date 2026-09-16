# Deployment

## 1. Supabase project

1. Create a project at [supabase.com](https://supabase.com).
2. Note the project URL and the **publishable (anon) key** from
   **Project Settings → API**. Never use the service-role key here or
   anywhere in the Flutter build — see `docs/DATABASE.md`'s security section
   for why.
3. Apply every migration in order:

   ```bash
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```

   Or directly with `psql`, one file at a time in filename order (see
   `docs/DATABASE.md`).

4. Promote the first administrator. Create their account first (Supabase
   dashboard → Authentication → Add user, or have them sign up), then in the
   SQL editor:

   ```sql
   select public.bootstrap_super_admin('you@yourcompany.com');
   ```

   This refuses to run a second time once any super admin exists, so it
   cannot become a standing privilege-escalation path.

## 2. Edge Functions

One function exists so far: `invite-user`
(`supabase/functions/invite-user/index.ts`), which lets an administrator
create an account for a new employee without the service-role key ever
reaching the Flutter client. See the file's own header comment for the full
rationale and its authorisation model.

```bash
supabase functions deploy invite-user
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are
injected automatically into every Edge Function's environment by the
platform — nothing extra to configure.

> **Not verified by execution.** No Deno runtime or live Supabase project was
> available while writing this function. The code follows the documented
> Supabase Edge Functions and `supabase-js` v2 Admin API surface precisely,
> but treat the first deployment as its first real-world exercise, the same
> way the README flags Windows and iOS builds as unverified in this
> environment.

## 3. Firebase (push notifications)

1. Create a Firebase project and register the Android, iOS and Web apps.
2. Run `flutterfire configure` to generate `firebase_options.dart` (not
   committed — see `.gitignore`).
3. Upload the FCM server key to Supabase if reminders are dispatched from an
   Edge Function / `pg_cron` job rather than from the client.

## 4. Flutter builds

Every build takes its backend configuration through `--dart-define`; see the
table in the root `README.md`. Typical release builds:

```bash
flutter build web --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter build apk --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter build windows --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter build ipa --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Windows requires the Visual Studio "Desktop development with C++" workload;
iOS requires macOS and Xcode. Both are genuine platform requirements, not
project-specific setup — see the README's *Known toolchain issues* section
for the Android-specific Gradle/Kotlin notes this project needed.

## 5. CI secrets

Never commit `SUPABASE_ANON_KEY`, Firebase config, or any signing credential.
In CI, inject them as masked secrets and pass them through `--dart-define` at
build time, exactly as a local build does.
