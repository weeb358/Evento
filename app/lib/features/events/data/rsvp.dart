import 'package:equatable/equatable.dart';

enum RsvpStatus { going, interested }

RsvpStatus rsvpStatusFromString(String value) =>
    value == 'going' ? RsvpStatus.going : RsvpStatus.interested;

class Rsvp extends Equatable {
  const Rsvp({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String userId;
  final RsvpStatus status;
  final DateTime createdAt;

  factory Rsvp.fromJson(Map<String, dynamic> json) {
    return Rsvp(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      status: rsvpStatusFromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, eventId, userId, status, createdAt];
}
