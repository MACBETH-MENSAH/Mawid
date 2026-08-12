import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks how many unread notifications the current user has, updating
/// live via a Supabase Realtime subscription rather than polling — the
/// moment a new notifications row is inserted for this user (from any of
/// the database triggers: registration confirmed, checked in, reminder,
/// event cancelled), the badge updates without the app needing to ask.
class NotificationsProvider with ChangeNotifier {
  int unreadCount = 0;
  RealtimeChannel? _channel;
  String? _attachedUserId;

  /// Call this whenever the current user is known/changes (see
  /// MawidTopBar, which calls it on every build — cheap, since it's a
  /// no-op if already attached to this same user).
  void attach(String userId) {
    if (_attachedUserId == userId) return;
    _detach();
    _attachedUserId = userId;
    _loadInitialCount(userId);

    _channel = Supabase.instance.client
        .channel('notifications-badge-$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        unreadCount++;
        notifyListeners();
      },
    )
        .subscribe();
  }

  Future<void> _loadInitialCount(String userId) async {
    final rows = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    unreadCount = (rows as List).length;
    notifyListeners();
  }

  /// Called when the Notifications screen is opened and marks everything
  /// read, so the badge clears immediately instead of waiting on a
  /// round-trip.
  void clearUnread() {
    unreadCount = 0;
    notifyListeners();
  }

  void _detach() {
    _channel?.unsubscribe();
    _channel = null;
    _attachedUserId = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}