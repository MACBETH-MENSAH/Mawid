class Registration {
  final String id;
  final String userId;
  final String eventId;
  final String ticketTypeId;
  final String ticketCode;
  final String status; // 'booked' | 'checked_in' | 'cancelled'
  final DateTime createdAt;

  Registration({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.ticketTypeId,
    required this.ticketCode,
    required this.status,
    required this.createdAt,
  });

  factory Registration.fromJson(Map<String, dynamic> json) {
    return Registration(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      ticketTypeId: json['ticket_type_id'] as String,
      ticketCode: json['ticket_code'] as String,
      status: json['status'] as String? ?? 'booked',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'event_id': eventId,
      'ticket_type_id': ticketTypeId,
    };
  }

  bool get isCheckedIn => status == 'checked_in';
  bool get isCancelled => status == 'cancelled';
}
