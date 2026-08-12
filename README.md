# MAWID

**Your next occasion.**

MAWID (from Arabic *mawʿid* — an appointed time, occasion, or gathering) is
an event management app: create and manage events, sell/give out tickets,
let attendees discover and register for events, and check people in on
the day — all in one account, with no separate "organizer" vs "attendee"
sign-up. Built as a Software Engineering course project.

## Features

- Email/password auth (Supabase Auth)
- Create, edit, publish, cancel, and delete events
- Multiple ticket types per event, each with its own price and quantity
- Browse/search events by name and category
- Register for one or more ticket types in a single checkout
- Digital QR ticket per registration
- Organizer dashboard: registrant list, check-in stats, revenue
- Check-in via camera QR scan or manual search/code entry
- Real-time notifications (registration confirmed, checked in, event
  reminders, event cancelled) with a live unread badge, plus per-type
  notification preferences
- Profile photo upload, editable profile
- Full account deletion (via a secure server-side function)

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| State management | Provider |
| Backend | Supabase (Postgres, Auth, Storage, Realtime, Edge Functions) |
| Ticket QR | qr_flutter |
| Check-in scanning | mobile_scanner |

## Project structure

```
lib/
├── config/         # Supabase URL/key (fill in your own — see Setup)
├── models/         # Plain Dart classes matching the DB schema
├── providers/      # App-wide state (auth, live data refresh signal, notifications)
├── services/       # All Supabase queries, grouped by domain
├── screens/        # One folder per feature area
├── theme/          # Colors and ThemeData — the dark navy/blue design system
├── widgets/         # Shared widgets (logo, top bar, event card, etc.)
└── main.dart

supabase/
└── functions/
    └── delete-account/   # Edge Function for secure full account deletion

*.sql                     # Database schema + additive migrations, run in order
```

## Setup

1. Create a Supabase project.
2. Run the SQL files in this repo, **in order**, in Supabase's SQL Editor:
   `eventhive_schema.sql` → `stage4_migration.sql` → `stage4b_migration.sql`
   → `stage4c_migration.sql`.
3. Deploy the Edge Function in `supabase/functions/delete-account` (via
   Supabase's dashboard Edge Functions editor, or the CLI).
4. Copy your project's URL and anon key (Project Settings → API) into
   `lib/config/supabase_config.dart`.
5. `flutter pub get`
6. Add camera permission for the check-in scanner:
    - Android: `<uses-permission android:name="android.permission.CAMERA" />`
      in `android/app/src/main/AndroidManifest.xml`
    - iOS: `NSCameraUsageDescription` key in `ios/Runner/Info.plist`
7. `flutter run`

## Database design

Four core tables (`profiles`, `events`, `ticket_types`, `registrations`)
plus `notifications`, all with Row Level Security policies scoping access
to what each user should actually be able to see/change. Ticket oversell
is prevented at the database level via a trigger, not just app-side
validation. See `eventhive_schema.sql` for the full schema and comments.

## Academic context

Built for a Software Engineering course project. UI design referenced
against the Vaurse app for layout/interaction patterns (see project
documentation for details); MAWID's brand identity, color system, and all
functionality are original to this project.
