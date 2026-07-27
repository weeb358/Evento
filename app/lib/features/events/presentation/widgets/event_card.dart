import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/saved/saved_event_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/event.dart';

class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedIdsAsync = ref.watch(savedEventIdsProvider);
    final isSaved = savedIdsAsync.valueOrNull?.contains(event.id) ?? false;
    final isSignedIn = ref.watch(currentUserIdProvider) != null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push('/events/${event.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: event.coverImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: event.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => _CoverFallback(theme: theme),
                          )
                        : _CoverFallback(theme: theme),
                  ),
                ),
                if (event.isFeatured)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _Pill(label: 'FEATURED', color: theme.colorScheme.primary),
                  ),
                if (isSignedIn)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: _BookmarkButton(event: event, isSaved: isSaved),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              event.title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormat('EEE, MMM d · h:mm a').format(event.startTime)} · ${event.city}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              event.isFree ? 'Free' : 'Rs ${event.price.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.event_rounded, color: theme.colorScheme.onSurfaceVariant, size: 32),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.event, required this.isSaved});

  final Event event;
  final bool isSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(
          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () async {
          final userId = ref.read(currentUserIdProvider);
          if (userId == null) return;
          await ref
              .read(savedEventRepositoryProvider)
              .toggleDefaultBookmark(userId: userId, eventId: event.id);
          ref.invalidate(savedEventIdsProvider);
        },
      ),
    );
  }
}
