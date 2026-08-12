class EventModel {
  final String id;
  final String organizerId;
  final String title;
  final String? description;
  final String? category;
  final String? venue;
  final double? latitude;
  final double? longitude;
  final String? coverImageUrl;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'draft' | 'published' | 'cancelled'
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    this.category,
    this.venue,
    this.latitude,
    this.longitude,
    this.coverImageUrl,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      organizerId: json['organizer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      venue: json['venue'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      coverImageUrl: json['cover_image_url'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'organizer_id': organizerId,
      'title': title,
      'description': description,
      'category': category,
      'venue': venue,
      'latitude': latitude,
      'longitude': longitude,
      'cover_image_url': coverImageUrl,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
    };
  }

  bool isOrganizedBy(String userId) => organizerId == userId;
}
