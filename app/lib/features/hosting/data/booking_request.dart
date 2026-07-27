import 'package:equatable/equatable.dart';

enum BookingStatus { pending, accepted, declined, cancelled, completed }

BookingStatus bookingStatusFromString(String value) {
  return BookingStatus.values.firstWhere((s) => s.name == value, orElse: () => BookingStatus.pending);
}

class BookingRequest extends Equatable {
  const BookingRequest({
    required this.id,
    required this.hostId,
    required this.guestId,
    required this.startDate,
    required this.endDate,
    required this.guestsCount,
    this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String hostId;
  final String guestId;
  final DateTime startDate;
  final DateTime endDate;
  final int guestsCount;
  final String? message;
  final BookingStatus status;
  final DateTime createdAt;

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      guestId: json['guest_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      guestsCount: json['guests_count'] as int,
      message: json['message'] as String?,
      status: bookingStatusFromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, hostId, guestId, startDate, endDate, guestsCount, message, status, createdAt];
}
