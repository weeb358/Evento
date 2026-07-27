import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/result.dart';
import 'review.dart';

class ReviewRepository {
  ReviewRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<Review>>> getReviewsFor({
    required ReviewSubjectType subjectType,
    required String subjectId,
  }) {
    return guard(() async {
      final rows = await _client
          .from('reviews')
          .select()
          .eq('subject_type', reviewSubjectTypeToString(subjectType))
          .eq('subject_id', subjectId)
          .order('created_at', ascending: false);
      return rows.map(Review.fromJson).toList();
    });
  }

  Future<Result<Review>> submitReview({
    required ReviewSubjectType subjectType,
    required String subjectId,
    required String reviewerId,
    required int rating,
    String? text,
  }) {
    return guard(() async {
      final row = await _client
          .from('reviews')
          .upsert({
            'subject_type': reviewSubjectTypeToString(subjectType),
            'subject_id': subjectId,
            'reviewer_id': reviewerId,
            'rating': rating,
            'text': text,
          }, onConflict: 'subject_type,subject_id,reviewer_id')
          .select()
          .single();
      return Review.fromJson(row);
    });
  }
}
