import '../models/ticket_type.dart';

/// One line item in a checkout: "N of this ticket type".
/// Used to support buying multiple ticket types (and multiple quantities)
/// in a single registration flow, instead of being locked to exactly one
/// ticket type at quantity 1.
class TicketSelection {
  final TicketType ticketType;
  final int quantity;

  const TicketSelection({required this.ticketType, required this.quantity});

  double get subtotal => ticketType.price * quantity;
}