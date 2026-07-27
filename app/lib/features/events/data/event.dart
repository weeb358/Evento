import 'package:equatable/equatable.dart';

enum EventStatus { draft, published, cancelled }

EventStatus eventStatusFromString(String value) {
  return EventStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => EventStatus.published,
  );
}

class Event extends Equatable {
  const Event({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    required this.category,
    required this.city,
    this.venueName,
    this.lat,
    this.lng,
    required this.startTime,
    this.endTime,
    required this.price,
    this.capacity,
    this.coverImageUrl,
    required this.status,
    required this.isFeatured,
    this.premiumRsvpOpensAt,
    this.templateId,
    required this.createdAt,
  });

  final String id;
  final String organizerId;
  final String title;
  final String? description;
  final String category;
  final String city;
  final String? venueName;
  final double? lat;
  final double? lng;
  final DateTime startTime;
  final DateTime? endTime;
  final double price;
  final int? capacity;
  final String? coverImageUrl;
  final EventStatus status;
  final bool isFeatured;
  final DateTime? premiumRsvpOpensAt;
  final String? templateId;
  final DateTime createdAt;

  bool get isFree => price <= 0;
  bool get hasLocation => lat != null && lng != null;

  /// True while a capacity-limited event is still inside its Premium
  /// early-access RSVP window — Standard users can't RSVP yet.
  bool isInEarlyAccessWindow(DateTime now) {
    final opensAt = premiumRsvpOpensAt;
    return opensAt != null && now.isBefore(opensAt);
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      organizerId: json['organizer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      city: json['city'] as String,
      venueName: json['venue_name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      price: (json['price'] as num).toDouble(),
      capacity: json['capacity'] as int?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: eventStatusFromString(json['status'] as String),
      isFeatured: json['is_featured'] as bool? ?? false,
      premiumRsvpOpensAt: json['premium_rsvp_opens_at'] != null
          ? DateTime.parse(json['premium_rsvp_opens_at'] as String)
          : null,
      templateId: json['template_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    organizerId,
    title,
    description,
    category,
    city,
    venueName,
    lat,
    lng,
    startTime,
    endTime,
    price,
    capacity,
    coverImageUrl,
    status,
    isFeatured,
    premiumRsvpOpensAt,
    templateId,
    createdAt,
  ];
}

const kEventCategories = [
  'Concert',
  'Meetup',
  'Workshop',
  'University',
  'Food Festival',
  'Sports',
  'Conference',
  'Other',
];
