import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/reviews/review.dart';
import '../../../../core/reviews/review_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../chat/presentation/controllers/chat_providers.dart';
import '../../data/host_profile.dart';
import '../../data/host_repository.dart';
import '../controllers/hosting_providers.dart';

class HostDetailScreen extends ConsumerWidget {
  const HostDetailScreen({super.key, required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hostAsync = ref.watch(hostProfileProvider(hostId));
    final profileAsync = ref.watch(userProfileProvider(hostId));
    final photosAsync = ref.watch(hostPhotosProvider(hostId));
    final availabilityAsync = ref.watch(hostAvailabilityProvider(hostId));
    final reviewsAsync = ref.watch(reviewsForSubjectProvider((type: ReviewSubjectType.user, id: hostId)));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnProfile = currentUserId == hostId;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!isOwnProfile && currentUserId != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => context.push('/reports/new?targetType=user&targetId=$hostId'),
            ),
        ],
      ),
      body: hostAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (host) {
          if (host == null) {
            return const EmptyState(icon: Icons.night_shelter_outlined, title: 'Listing not found');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _PhotoStrip(photosAsync: photosAsync),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  AppAvatar(photoUrl: profileAsync.valueOrNull?.photoUrl, name: profileAsync.valueOrNull?.name, radius: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(profileAsync.valueOrNull?.name ?? '...', style: theme.textTheme.titleLarge),
                            if (host.isVerified) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.verified_rounded, size: 18, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        if (host.headline != null) Text(host.headline!, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (host.homeType != null) Chip(label: Text(homeTypeLabel(host.homeType!))),
                  if (host.maxGuests != null) Chip(label: Text('Up to ${host.maxGuests} guests')),
                  if (host.city != null) Chip(label: Text(host.city!)),
                ],
              ),
              if ((host.about ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('About', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(host.about!),
              ],
              if ((host.houseRules ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('House rules', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(host.houseRules!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Availability', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              availabilityAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (slots) {
                  if (slots.isEmpty) {
                    return Text(
                      'No open dates listed — ask the host directly.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: slots
                        .map(
                          (slot) => Text(
                            '${DateFormat('MMM d').format(slot.startDate)} – ${DateFormat('MMM d, y').format(slot.endDate)}'
                            '${slot.note != null ? ' · ${slot.note}' : ''}',
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Reviews', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              reviewsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return Text(
                      'No reviews yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    );
                  }
                  return Column(
                    children: reviews
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text('${r.rating}'),
                                  const SizedBox(width: AppSpacing.sm),
                                  if ((r.text ?? '').isNotEmpty) Expanded(child: Text(r.text!)),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (!isOwnProfile && currentUserId != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.push('/hosting/$hostId/request'),
                    child: const Text('Request to stay'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Message host'),
                    onPressed: () async {
                      final result = await ref.read(chatRepositoryProvider).getOrCreateDirectThread(hostId);
                      if (!context.mounted) return;
                      result.when(
                        ok: (threadId) => context.push('/chat/$threadId'),
                        err: (failure) => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(failure.message)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photosAsync});

  final AsyncValue<List<HostPhoto>> photosAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return photosAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (photos) {
        if (photos.isEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              height: 180,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.night_shelter_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: CachedNetworkImage(imageUrl: photos[index].url, width: 260, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}
