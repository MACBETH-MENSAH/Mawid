# MAWID — Full Setup Guide

One consolidated reference, replacing the separate STAGE1–4 notes files
from earlier in the build. Follow this top to bottom for a fresh setup
(new machine, new Supabase project, or onboarding a teammate).

## 1. Supabase project
1. Create a project at supabase.com (region: closest to you — Europe for
   Ghana-based users).
2. On creation, keep these enabled: **Enable Data API**, **Enable
   automatic RLS**. "Automatically expose new tables" can stay on too.

## 2. Run the SQL migrations, in this exact order
All four live in the project root. Supabase dashboard → **SQL Editor** →
New query → paste → Run, one file at a time:

1. `eventhive_schema.sql` — core tables (profiles, events, ticket_types,
   registrations), RLS policies, oversell-prevention trigger.
2. `stage4_migration.sql` — notifications table + registration/check-in
   notification triggers + missing profiles delete policy.
3. `stage4b_migration.sql` — avatar storage bucket + policies,
   notification preference columns, triggers updated to respect them.
4. `stage4c_migration.sql` — Realtime enabled on notifications, scheduled
   event reminders (`pg_cron`), cancel-event notification trigger.
    - If `create extension if not exists pg_cron;` errors on permissions:
      Supabase dashboard → Database → Extensions → search "pg_cron" →
      enable manually, then re-run just the `select cron.schedule(...)`
      block from that file.

## 3. Deploy the delete-account Edge Function
Supabase dashboard → **Edge Functions** → Create a new function named
exactly `delete-account` → replace all the starter code with the contents
of `supabase/functions/delete-account/index.ts` → Deploy. No environment
variables to set manually — Supabase injects `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` automatically.

## 4. Configure the Flutter app
1. Supabase dashboard → Project Settings → API → copy the **Project
   URL** and **anon public** key (never the service_role key).
2. Paste both into `lib/config/supabase_config.dart`.
3. `flutter pub get`

## 5. Camera permission (needed for the check-in QR scanner)
**Android** — `android/app/src/main/AndroidManifest.xml`, inside
`<manifest>`, above `<application>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** — `ios/Runner/Info.plist`, inside the outer `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>MAWID needs camera access to scan attendee ticket QR codes.</string>
```

## 6. Run it
```
flutter run
```
or for faster iteration during development:
```
flutter run -d chrome
```

## Testing tips
- Camera QR scanning is unreliable on emulators — use the **Search
  manually** button on the scanner screen, or the **Check in** button per
  row on the Event Dashboard's registrant list, to test check-in without
  a working camera feed.
- To trigger a reminder notification immediately instead of waiting for
  the 30-minute cron job: SQL Editor → `select public.send_event_reminders();`
- Turn off email confirmation for faster signup testing: Supabase
  dashboard → Authentication → Providers → Email → toggle off "Confirm
  email." Remember to weigh whether to turn it back on before any real
  deployment/demo where you want to show it's a considered decision, not
  an oversight.

## Known, disclosed limitations (fine to mention as-is in your report)
- Buying multiple tickets in one checkout isn't wrapped in a single
  atomic database transaction — see the comment in
  `booking_confirmation_screen.dart` for the reasoning and what a
  production version would do differently.
- Event cover images are set via a pasted URL, not a direct device photo
  upload (unlike avatars, which do upload directly to Storage) — see the
  next section if you want this changed.