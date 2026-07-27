import 'package:equatable/equatable.dart';

class EventTemplate extends Equatable {
  const EventTemplate({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    required this.category,
    required this.city,
    this.venueName,
    this.lat,
    this.lng,
    required this.durationMinutes,
    required this.price,
    this.capacity,
    this.coverImageUrl,
    required this.recurrenceRule,
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
  final int durationMinutes;
  final double price;
  final int? capacity;
  final String? coverImageUrl;
  final Map<String, dynamic> recurrenceRule;
  final DateTime createdAt;

  int get occurrenceCount => (recurrenceRule['count'] as num?)?.toInt() ?? 4;
  int get intervalWeeks => (recurrenceRule['interval'] as num?)?.toInt() ?? 1;

  factory EventTemplate.fromJson(Map<String, dynamic> json) {
    return EventTemplate(
      id: json['id'] as String,
      organizerId: json['organizer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      city: json['city'] as String,
      venueName: json['venue_name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      price: (json['price'] as num).toDouble(),
      capacity: json['capacity'] as int?,
      coverImageUrl: json['cover_image_url'] as String?,
      recurrenceRule: Map<String, dynamic>.from(json['recurrence_rule'] as Map),
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
    durationMinutes,
    price,
    capacity,
    coverImageUrl,
    recurrenceRule,
    createdAt,
  ];
}
