import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket_type.dart';

class TicketService {
  TicketService._();
  static final TicketService instance = TicketService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<TicketType>> fetchTicketTypesForEvent(String eventId) async {
    final rows = await _client
        .from('ticket_types')
        .select()
        .eq('event_id', eventId)
        .order('price', ascending: true);
    return (rows as List).map((r) => TicketType.fromJson(r)).toList();
  }
}
