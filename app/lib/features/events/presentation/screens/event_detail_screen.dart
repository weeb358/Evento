import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/premium/premium_gate.dart';
import '../../../../core/reviews/review.dart';
import '../../../../core/reviews/review_providers.dart';
import '../../../../core/saved/saved_event_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/error_state.dart';
import '../../data/event.dart';
import '../../data/rsvp.dart';
import '../controllers/event_providers.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final currentUserId = ref.watch(currentUserIdProvider);

    ref.listen(eventDetailProvider(eventId), (previous, next) {
      if (previous == null) {
        ref.read(eventRepositoryProvider).recordView(eventId: eventId, viewerId: currentUserId);
      }
    });

    return Scaffold(
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(failure: AppFailure.fromException(error)),
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found'));
          }
          return _EventDetailBody(event: event, currentUserId: currentUserId);
        },
      ),
    );
  }
}

class _EventDetailBody extends ConsumerWidget {
  const _EventDetailBody({required this.event, required this.currentUserId});

  final Event event;
  final String? currentUserId;

  bool get _isOrganizer => currentUserId != null && currentUserId == event.organizerId;
  bool get _isPast => event.startTime.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organizerAsync = ref.watch(userProfileProvider(event.organizerId));
    final savedIdsAsync = ref.watch(savedEventIdsProvider);
    final isSaved = savedIdsAsync.valueOrNull?.contains(event.id) ?? false;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          actions: [
            if (currentUserId != null)
              IconButton(
                icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                onPressed: () async {
                  await ref
                      .read(savedEventRepositoryProvider)
                      .toggleDefaultBookmark(userId: currentUserId!, eventId: event.id);
                  ref.invalidate(savedEventIdsProvider);
                },
              ),
            if (_isOrganizer) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/events/${event.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                onPressed: () => context.push('/organizer/analytics/${event.id}'),
              ),
            ] else if (currentUserId != null)
              IconButton(
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => context.push(
                  '/reports/new?targetType=event&targetId=${event.id}',
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: event.coverImageUrl != null
                ? CachedNetworkImage(imageUrl: event.coverImageUrl!, fit: BoxFit.cover)
                : Container(color: theme.colorScheme.surfaceContainerHighest),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (event.isFeatured) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(event.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                text: DateFormat('EEEE, MMM d, y · h:mm a').format(event.startTime),
              ),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: [event.venueName, event.city].where((s) => (s ?? '').isNotEmpty).join(', '),
              ),
              _InfoRow(
                icon: Icons.attach_money_rounded,
                text: event.isFree ? 'Free' : 'Rs ${event.price.toStringAsFixed(0)}',
              ),
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => context.push('/profile/${event.organizerId}'),
                child: Row(
                  children: [
                    AppAvatar(
                      photoUrl: organizerAsync.valueOrNull?.photoUrl,
                      name: organizerAsync.valueOrNull?.name,
                      radius: 16,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Hosted by ${organizerAsync.valueOrNull?.name ?? '...'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if ((event.description ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(event.description!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (!_isPast) _RsvpSection(event: event, currentUserId: currentUserId),
              const SizedBox(height: AppSpacing.xl),
              _AttendeesSection(eventId: event.id),
              const SizedBox(height: AppSpacing.xl),
              _ReviewsSection(event: event, currentUserId: currentUserId, isPast: _isPast),
              const SizedBox(height: AppSpacing.xxl),
            ]),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _RsvpSection extends ConsumerWidget {
  const _RsvpSection({required this.event, required this.currentUserId});

  final Event event;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countsAsync = ref.watch(rsvpCountsProvider(event.id));
    final myRsvpAsync = currentUserId == null
        ? const AsyncValue<Rsvp?>.data(null)
        : ref.watch(myRsvpProvider(event.id));

    final isEarlyAccess = event.isInEarlyAccessWindow(DateTime.now());
    final isPremium = ref.watch(currentUserProfileProvider).valueOrNull?.isPremium ?? false;
    final rsvpLocked = isEarlyAccess && !isPremium;

    Future<void> setStatus(RsvpStatus status) async {
      if (currentUserId == null) {
        context.push('/auth/email-login');
        return;
      }
      final myRsvp = myRsvpAsync.valueOrNull;
      if (myRsvp?.status == status) {
        await ref.read(rsvpRepositoryProvider).removeRsvp(eventId: event.id, userId: currentUserId!);
      } else {
        await ref.read(rsvpRepositoryProvider).setRsvp(
              eventId: event.id,
              userId: currentUserId!,
              status: status,
            );
      }
      ref.invalidate(myRsvpProvider(event.id));
      ref.invalidate(rsvpCountsProvider(event.id));
    }

    final counts = countsAsync.valueOrNull ?? (going: 0, interested: 0);
    final myStatus = myRsvpAsync.valueOrNull?.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${counts.going} going · ${counts.interested} interested', style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        if (rsvpLocked)
          PremiumGate(
            featureName: 'Early access RSVP',
            description:
                'Premium members can RSVP now. Opens to everyone at ${DateFormat('MMM d, h:mm a').format(event.premiumRsvpOpensAt!)}.',
            child: const SizedBox.shrink(),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setStatus(RsvpStatus.going),
                  icon: Icon(myStatus == RsvpStatus.going ? Icons.check_circle_rounded : Icons.check_circle_outline),
                  label: const Text('Going'),
                  style: myStatus == RsvpStatus.going
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setStatus(RsvpStatus.interested),
                  icon: Icon(myStatus == RsvpStatus.interested ? Icons.star_rounded : Icons.star_outline_rounded),
                  label: const Text('Interested'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _AttendeesSection extends ConsumerWidget {
  const _AttendeesSection({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PremiumGate(
      featureName: 'See who else is going',
      description: 'Premium members can see the full attendee list.',
      child: Consumer(
        builder: (context, ref, _) {
          final attendeesAsync = ref.watch(eventAttendeesProvider(eventId));
          return attendeesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (attendees) {
              if (attendees.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Who\'s going', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: attendees.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final userId = attendees[index].userId;
                        final profileAsync = ref.watch(userProfileProvider(userId));
                        return AppAvatar(
                          photoUrl: profileAsync.valueOrNull?.photoUrl,
                          name: profileAsync.valueOrNull?.name,
                          radius: 18,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection({required this.event, required this.currentUserId, required this.isPast});

  final Event event;
  final String? currentUserId;
  final bool isPast;

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  int _rating = 5;
  final _textController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.currentUserId == null) return;
    setState(() => _isSubmitting = true);
    await ref.read(reviewRepositoryProvider).submitReview(
          subjectType: ReviewSubjectType.event,
          subjectId: widget.event.id,
          reviewerId: widget.currentUserId!,
          rating: _rating,
          text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
        );
    ref.invalidate(reviewsForSubjectProvider((type: ReviewSubjectType.event, id: widget.event.id)));
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(
      reviewsForSubjectProvider((type: ReviewSubjectType.event, id: widget.event.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (widget.isPast && widget.currentUserId != null) ...[
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                icon: Icon(
                  starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => setState(() => _rating = starIndex),
              );
            }),
          ),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(hintText: 'Share your experience (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: const Text('Post review'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
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
              children: reviews.map((review) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('${review.rating}', style: theme.textTheme.labelMedium),
                      const SizedBox(width: AppSpacing.sm),
                      if ((review.text ?? '').isNotEmpty) Expanded(child: Text(review.text!)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
