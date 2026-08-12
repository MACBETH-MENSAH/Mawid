import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/profile.dart';
import '../models/registration.dart';
import '../models/ticket_type.dart';

/// One event the user is attending, with how many tickets they hold for
/// it. A user can register more than once for the same event (e.g. two
/// different ticket types, or several of the same type) — grouping by
/// event here is what stops that from showing as N duplicate cards in
/// "My upcoming events" / the Attending tab; instead it shows one card
/// with a "N TICKETS" badge.
class AttendingEventSummary {
  final EventModel event;
  final int ticketCount;
  const AttendingEventSummary({required this.event, required this.ticketCount});
}

class RegistrationService {
  RegistrationService._();
  static final RegistrationService instance = RegistrationService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Books a ticket. The DB trigger `book_ticket()` (see eventhive_schema.sql)
  /// atomically increments quantity_sold and rejects the insert if the
  /// ticket type is sold out — so a race between two people booking the
  /// last ticket is handled by the database, not by app-side checks.
  Future<Registration> createRegistration({
    required String userId,
    required String eventId,
    required String ticketTypeId,
  }) async {
    final row = await _client
        .from('registrations')
        .insert({
      'user_id': userId,
      'event_id': eventId,
      'ticket_type_id': ticketTypeId,
    })
        .select()
        .single();
    return Registration.fromJson(row);
  }

  /// A user's registrations, most recent first. Used by the Activity
  /// screen's "Attending" tab and to look up a ticket for the QR screen.
  Future<List<Map<String, dynamic>>> fetchRegistrationsWithEvents(
      String userId) async {
    final rows = await _client
        .from('registrations')
        .select('*, events(*), ticket_types(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Events the user is attending, grouped so each event appears once
  /// with a ticket count — this is the fix for events appearing as
  /// duplicate cards when someone holds more than one ticket for the
  /// same event. Excludes cancelled registrations. Set [upcomingOnly] to
  /// filter out events whose start date has already passed (used by
  /// Home's "My upcoming events" and Activity's Attending tab — past
  /// events they attended aren't "upcoming" and shouldn't appear there,
  /// even though the event itself may still be publicly browsable until
  /// its organizer removes it).
  Future<List<AttendingEventSummary>> fetchAttendingSummaries(
      String userId, {
        bool upcomingOnly = false,
      }) async {
    final rows = await _client
        .from('registrations')
        .select('event_id, status, events(*)')
        .eq('user_id', userId)
        .neq('status', 'cancelled');

    final counts = <String, int>{};
    final events = <String, EventModel>{};
    for (final row in rows) {
      final eventJson = row['events'] as Map<String, dynamic>?;
      if (eventJson == null) continue; // event was deleted
      final event = EventModel.fromJson(eventJson);
      counts[event.id] = (counts[event.id] ?? 0) + 1;
      events[event.id] = event;
    }

    final now = DateTime.now();
    var summaries = events.values
        .map((e) =>
        AttendingEventSummary(event: e, ticketCount: counts[e.id] ?? 1))
        .toList();

    if (upcomingOnly) {
      summaries = summaries.where((s) => s.event.startDate.isAfter(now)).toList();
    }

    summaries.sort((a, b) => a.event.startDate.compareTo(b.event.startDate));
    return summaries;
  }

  /// This user's individual tickets (registrations) for one specific
  /// event, each paired with its ticket type. Used on Event Details to
  /// show "Your tickets for this event" so a user can actually get back
  /// to a ticket they already bought, instead of only ever seeing an
  /// option to buy another one.
  Future<List<(Registration, TicketType)>> fetchUserRegistrationsForEvent(
      String userId,
      String eventId,
      ) async {
    final rows = await _client
        .from('registrations')
        .select('*, ticket_types(*)')
        .eq('user_id', userId)
        .eq('event_id', eventId)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      final registration = Registration.fromJson(row);
      final ticketType =
      TicketType.fromJson(row['ticket_types'] as Map<String, dynamic>);
      return (registration, ticketType);
    }).toList();
  }

  /// Registrants for one event — used by the organizer's Event Dashboard.
  Future<List<Map<String, dynamic>>> fetchRegistrantsForEvent(
      String eventId) async {
    final rows = await _client
        .from('registrations')
        .select('*, profiles(*), ticket_types(*)')
        .eq('event_id', eventId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markCheckedIn(String registrationId) async {
    await _client
        .from('registrations')
        .update({'status': 'checked_in'})
        .eq('id', registrationId);
  }

  /// Looks up a registration by its scanned ticket code, scoped to one
  /// event — scoping to the event matters so a QR code from a different
  /// event (or a bogus scan) can't accidentally check someone in to the
  /// wrong thing. Returns null if no match, so the scanner screen can
  /// show "not found" rather than crashing.
  Future<(Registration, Profile)?> findByTicketCode({
    required String eventId,
    required String ticketCode,
  }) async {
    final row = await _client
        .from('registrations')
        .select('*, profiles(*)')
        .eq('event_id', eventId)
        .eq('ticket_code', ticketCode.trim())
        .maybeSingle();

    if (row == null) return null;
    final registration = Registration.fromJson(row);
    final profile = Profile.fromJson(row['profiles'] as Map<String, dynamic>);
    return (registration, profile);
  }
}