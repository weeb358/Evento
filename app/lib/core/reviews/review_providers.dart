import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'review.dart';
import 'review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider));
});

typedef ReviewSubjectKey = ({ReviewSubjectType type, String id});

final reviewsForSubjectProvider = FutureProvider.family<List<Review>, ReviewSubjectKey>((ref, key) async {
  final result = await ref
      .watch(reviewRepositoryProvider)
      .getReviewsFor(subjectType: key.type, subjectId: key.id);
  return result.when(ok: (reviews) => reviews, err: (_) => []);
});

double averageRating(List<Review> reviews) {
  if (reviews.isEmpty) return 0;
  return reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
}
