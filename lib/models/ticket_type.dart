class TicketType {
  final String id;
  final String eventId;
  final String name;
  final double price;
  final int quantityAvailable;
  final int quantitySold;

  TicketType({
    required this.id,
    required this.eventId,
    required this.name,
    required this.price,
    required this.quantityAvailable,
    required this.quantitySold,
  });

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantityAvailable: json['quantity_available'] as int,
      quantitySold: json['quantity_sold'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'event_id': eventId,
      'name': name,
      'price': price,
      'quantity_available': quantityAvailable,
    };
  }

  int get remaining {
    final diff = quantityAvailable - quantitySold;
    return diff < 0 ? 0 : diff;
  }
  bool get isSoldOut => remaining <= 0;
  bool get isFree => price == 0;
}