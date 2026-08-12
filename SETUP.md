# MAWID — Stage 1 (Foundation + Auth)

## What's in this stage
- Theme system (`lib/theme/`) — the dark navy/blue palette, one place to change it
- Models (`lib/models/`) — Profile, EventModel, TicketType, Registration — field
  names map 1:1 to the columns in `eventhive_schema.sql`
- Supabase wiring (`lib/services/supabase_service.dart`, `lib/providers/auth_provider.dart`)
- Login + Sign Up screens, fully working against Supabase Auth
- `MawidLogo` widget — the one place the brand mark is referenced from
- `main.dart` — routes to Login when logged out, to a placeholder Home
  screen when logged in (real Home comes in the next stage)

## How to run this
1. If you haven't already: `flutter create mawid` in your own environment,
   then replace the generated `lib/`, `pubspec.yaml`, and `assets/` with
   the ones in this zip (or merge them in if you've already started).
2. Run the Supabase schema (`eventhive_schema.sql`) in your Supabase
   project's SQL Editor if you haven't yet.
3. Open `lib/config/supabase_config.dart` and fill in your project's
   URL and anon key from Supabase dashboard -> Project Settings -> API.
4. `flutter pub get`
5. `flutter run`

You should be able to sign up, get a confirmation-email prompt (Supabase's
default), log in, and see a placeholder screen showing your name with a
log-out button. That confirms Auth + the `profiles` trigger are both wired
correctly before we build anything on top of them.

## Note on email confirmation
Supabase requires email confirmation by default, which will slow down
testing during your 2-day window. To turn it off for faster local testing:
Supabase dashboard -> Authentication -> Providers -> Email -> toggle off
"Confirm email". Turn it back on before anything resembling a real
deployment — just don't forget you turned it off, since "we deliberately
disabled email confirmation for local testing" is a completely reasonable
line for your report, "we forgot it was off" is not.

## Next stage
Home screen, Events browse/search, Filter modal, bottom nav (HomeShell)
tying Home/Events/Activity/Profile together. Say the word when ready.
