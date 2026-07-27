import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(supabaseClientProvider));
});

final eventAnalyticsProvider = FutureProvider.autoDispose.family<EventAnalytics?, String>((ref, eventId) async {
  final result = await ref.watch(analyticsRepositoryProvider).getEventAnalytics(eventId);
  return result.when(ok: (analytics) => analytics, err: (_) => null);
});

class EventAnalyticsScreen extends ConsumerWidget {
  const EventAnalyticsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analyticsAsync = ref.watch(eventAnalyticsProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Event analytics')),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load analytics'),
        data: (analytics) {
          if (analytics == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  _StatTile(label: 'Views', value: analytics.totalViews.toString()),
                  const SizedBox(width: AppSpacing.md),
                  _StatTile(label: 'Going', value: analytics.goingCount.toString()),
                  const SizedBox(width: AppSpacing.md),
                  _StatTile(label: 'Interested', value: analytics.interestedCount.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Views by day', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (analytics.viewsByDay.isEmpty)
                Text(
                  'No views yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                ...analytics.viewsByDay.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d').format(entry.day)),
                        Text('${entry.count} views'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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
