import 'package:flutter/foundation.dart';

/// A lightweight "something changed, you might want to refetch" signal.
///
/// Why this exists: HomeShell keeps all 4 tabs alive in memory
/// (IndexedStack) so switching tabs is instant. That's great for speed,
/// but it means a tab that already loaded its data has no way of knowing
/// when something happened elsewhere in the app that should invalidate
/// it — e.g. registering for an event on the Events tab should update
/// the "My upcoming events" list back on Home and the Attending tab on
/// Activity, even though neither of those screens did anything themselves.
///
/// Rather than manually wiring a refresh callback through every possible
/// navigation path (which is exactly what went wrong before — it's easy
/// to add a new action, like check-in, and forget one of the places that
/// needs to hear about it), screens that mutate shared data
/// (create/edit/delete event, register, check in) call `bump()` once on
/// success. Screens that display that data watch `version` and refetch
/// whenever it changes.
class DataRefreshProvider with ChangeNotifier {
  int version = 0;

  void bump() {
    version++;
    notifyListeners();
  }
}