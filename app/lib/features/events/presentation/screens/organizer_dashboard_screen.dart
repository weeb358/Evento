import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../data/event.dart';
import '../controllers/event_providers.dart';

class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(myOrganizerEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/events/create'),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(failure: AppFailure.fromException(error)),
        data: (events) {
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No events yet',
              message: 'Create your first event to see it here.',
              action: FilledButton(
                onPressed: () => context.push('/events/create'),
                child: const Text('Create event'),
              ),
            );
          }

          final now = DateTime.now();
          final upcoming = events.where((e) => e.startTime.isAfter(now)).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          final past = events.where((e) => !e.startTime.isAfter(now)).toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOrganizerEventsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _SummaryRow(events: events, upcomingCount: upcoming.length),
                const SizedBox(height: AppSpacing.xl),
                if (upcoming.isNotEmpty) ...[
                  Text('Upcoming', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...upcoming.map((e) => _OrganizerEventCard(event: e)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (past.isNotEmpty) ...[
                  Text('Past', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...past.map((e) => _OrganizerEventCard(event: e)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.events, required this.upcomingCount});

  final List<Event> events;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    final published = events.where((e) => e.status == EventStatus.published).length;
    return Row(
      children: [
        _StatTile(label: 'Total', value: events.length.toString()),
        const SizedBox(width: AppSpacing.md),
        _StatTile(label: 'Upcoming', value: upcomingCount.toString()),
        const SizedBox(width: AppSpacing.md),
        _StatTile(label: 'Published', value: published.toString()),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _OrganizerEventCard extends ConsumerWidget {
  const _OrganizerEventCard({required this.event});

  final Event event;

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final result = await ref
        .read(eventRepositoryProvider)
        .duplicateEvent(sourceId: event.id, organizerId: userId);
    if (!context.mounted) return;
    result.when(
      ok: (newEvent) {
        ref.invalidate(myOrganizerEventsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicated as a draft — review and publish it.')),
        );
        context.push('/events/${newEvent.id}/edit');
      },
      err: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text('Attendees will still see it marked as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel event')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(eventRepositoryProvider).updateEvent(
          id: event.id,
          status: EventStatus.cancelled,
        );
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(myOrganizerEventsProvider),
      err: (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this draft?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(eventRepositoryProvider).deleteEvent(event.id);
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(myOrganizerEventsProvider),
      err: (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(rsvpCountsProvider(event.id));
    final counts = countsAsync.valueOrNull ?? (going: 0, interested: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: () => context.push('/events/${event.id}'),
        title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${DateFormat('MMM d, y · h:mm a').format(event.startTime)}\n'
          '${counts.going} going · ${counts.interested} interested',
        ),
        isThreeLine: true,
        leading: _StatusChip(status: event.status),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                context.push('/events/${event.id}/edit');
              case 'analytics':
                context.push('/organizer/analytics/${event.id}');
              case 'duplicate':
                _duplicate(context, ref);
              case 'cancel':
                _cancel(context, ref);
              case 'delete':
                _delete(context, ref);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'analytics', child: Text('Analytics')),
            const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            if (event.status != EventStatus.cancelled)
              const PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
            if (event.status == EventStatus.draft)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = switch (status) {
      EventStatus.draft => (theme.colorScheme.onSurfaceVariant, 'DRAFT'),
      EventStatus.published => (theme.colorScheme.primary, 'LIVE'),
      EventStatus.cancelled => (theme.colorScheme.error, 'CANCELLED'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 9),
      ),
    );
  }
}
