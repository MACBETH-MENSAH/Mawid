class Profile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? avatarUrl;
  final bool notifyRegistration;
  final bool notifyCheckin;
  final bool notifyReminders;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
    this.avatarUrl,
    this.notifyRegistration = true,
    this.notifyCheckin = true,
    this.notifyReminders = true,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'attendee',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      notifyRegistration: json['notify_registration'] as bool? ?? true,
      notifyCheckin: json['notify_checkin'] as bool? ?? true,
      notifyReminders: json['notify_reminders'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar_url': avatarUrl,
      'notify_registration': notifyRegistration,
      'notify_checkin': notifyCheckin,
      'notify_reminders': notifyReminders,
    };
  }

  /// Initials for avatar placeholders, e.g. "Sarah Chen" -> "SC"
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}