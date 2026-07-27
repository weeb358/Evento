import 'package:equatable/equatable.dart';

enum ReviewSubjectType { event, user }

ReviewSubjectType reviewSubjectTypeFromString(String value) =>
    value == 'user' ? ReviewSubjectType.user : ReviewSubjectType.event;

String reviewSubjectTypeToString(ReviewSubjectType type) =>
    type == ReviewSubjectType.user ? 'user' : 'event';

class Review extends Equatable {
  const Review({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.reviewerId,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  final String id;
  final ReviewSubjectType subjectType;
  final String subjectId;
  final String reviewerId;
  final int rating;
  final String? text;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      subjectType: reviewSubjectTypeFromString(json['subject_type'] as String),
      subjectId: json['subject_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      rating: json['rating'] as int,
      text: json['text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, subjectType, subjectId, reviewerId, rating, text, createdAt];
}
