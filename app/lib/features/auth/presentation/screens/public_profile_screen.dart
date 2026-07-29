import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/reviews/review.dart';
import '../../../../core/reviews/review_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../chat/presentation/controllers/chat_providers.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider(userId));
    final reviewsAsync = ref.watch(
      reviewsForSubjectProvider((type: ReviewSubjectType.user, id: userId)),
    );

    ref.listen(userProfileProvider(userId), (previous, next) {
      if (previous == null) {
        ref.read(userProfileRepositoryProvider).recordProfileView(viewedUserId: userId);
      }
    });

    return Scaffold(
      appBar: AppBar(),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load profile'),
        data: (profile) {
          if (profile == null) {
            return const EmptyState(icon: Icons.person_off_outlined, title: 'Profile not found');
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  AppAvatar(photoUrl: profile.photoUrl, name: profile.name, radius: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(profile.name ?? 'Unnamed', style: theme.textTheme.titleLarge),
                            if (profile.isVerified) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.verified_rounded, size: 18, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        Text(
                          profile.city ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((profile.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(profile.bio!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (ref.watch(currentUserIdProvider) != null && ref.watch(currentUserIdProvider) != userId)
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                  onPressed: () async {
                    final result = await ref.read(chatRepositoryProvider).getOrCreateDirectThread(userId);
                    result.when(
                      ok: (threadId) => context.push('/chat/$threadId'),
                      err: (failure) => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(failure.message)),
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
              Text('Reviews', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              reviewsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text(
                        'No reviews yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: reviews
                        .map((review) => _ReviewTile(review: review))
                        .toList(growable: false),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewerAsync = ref.watch(userProfileProvider(review.reviewerId));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            photoUrl: reviewerAsync.valueOrNull?.photoUrl,
            name: reviewerAsync.valueOrNull?.name,
            radius: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(reviewerAsync.valueOrNull?.name ?? '...', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 6),
                    Icon(Icons.star_rounded, size: 14, color: theme.colorScheme.primary),
                    Text('${review.rating}', style: theme.textTheme.labelSmall),
                  ],
                ),
                if ((review.text ?? '').isNotEmpty)
                  Text(review.text!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
