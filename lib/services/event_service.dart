import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

/// All event-related Supabase queries live here, not scattered across
/// screens — same pattern as SupabaseService for auth.
class EventService {
  EventService._();
  static final EventService instance = EventService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Published events, most recent first. Used on Home + Browse Events.
  Future<List<EventModel>> fetchPublishedEvents({
    String? searchQuery,
    String? category,
  }) async {
    var query = _client.from('events').select().eq('status', 'published');

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }
    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }

    final rows = await query.order('start_date', ascending: true);
    return (rows as List).map((r) => EventModel.fromJson(r)).toList();
  }

  /// Events the current user has registered for (drives Home's "My
  /// upcoming events" and Activity's "Attending" tab). Joins through
  /// registrations -> events.
  Future<List<EventModel>> fetchAttendingEvents(String userId) async {
    final rows = await _client
        .from('registrations')
        .select('events(*)')
        .eq('user_id', userId)
        .neq('status', 'cancelled');

    return (rows as List)
        .map((r) => EventModel.fromJson(r['events'] as Map<String, dynamic>))
        .toList();
  }

  /// Events the current user created — powers Activity's "Organizing"
  /// tab. RLS already guarantees this only ever returns the caller's own
  /// events, but filtering explicitly here too keeps the query intent
  /// obvious to anyone reading this file later.
  Future<List<EventModel>> fetchOrganizedEvents(String userId) async {
    final rows = await _client
        .from('events')
        .select()
        .eq('organizer_id', userId)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => EventModel.fromJson(r)).toList();
  }

  Future<EventModel> fetchEventById(String eventId) async {
    final row =
    await _client.from('events').select().eq('id', eventId).single();
    return EventModel.fromJson(row);
  }

  /// Deleting an event cascades to delete its ticket_types and, through
  /// those, every registration tied to it (see eventhive_schema.sql's
  /// `on delete cascade`). Callers must confirm with the organizer first,
  /// especially when registrations already exist — see the confirmation
  /// dialog in activity_screen.dart's Organizing tab.
  Future<void> deleteEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }
}