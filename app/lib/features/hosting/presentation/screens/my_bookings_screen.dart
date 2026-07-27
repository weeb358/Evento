import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/booking_request.dart';
import '../controllers/hosting_providers.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My trips')),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (trips) {
          if (trips.isEmpty) {
            return const EmptyState(icon: Icons.card_travel_rounded, title: 'No trips booked yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: trips.length,
            itemBuilder: (context, index) => _TripTile(request: trips[index]),
          );
        },
      ),
    );
  }
}

class _TripTile extends ConsumerWidget {
  const _TripTile({required this.request});

  final BookingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(userProfileProvider(request.hostId));

    return Card(
      child: ListTile(
        onTap: () => context.push('/hosting/${request.hostId}'),
        leading: AppAvatar(photoUrl: hostAsync.valueOrNull?.photoUrl, name: hostAsync.valueOrNull?.name),
        title: Text('Stay with ${hostAsync.valueOrNull?.name ?? '...'}'),
        subtitle: Text(
          '${DateFormat('MMM d').format(request.startDate)} – ${DateFormat('MMM d, y').format(request.endDate)}',
        ),
        trailing: _StatusPill(status: request.status),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      BookingStatus.accepted => theme.colorScheme.primary,
      BookingStatus.declined || BookingStatus.cancelled => theme.colorScheme.error,
      BookingStatus.completed => theme.colorScheme.onSurfaceVariant,
      BookingStatus.pending => theme.colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(status.name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
