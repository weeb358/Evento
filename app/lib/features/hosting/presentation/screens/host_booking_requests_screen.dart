import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/booking_request.dart';
import '../controllers/hosting_providers.dart';

class HostBookingRequestsScreen extends ConsumerWidget {
  const HostBookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingBookingRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking requests')),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (requests) {
          if (requests.isEmpty) {
            return const EmptyState(icon: Icons.mail_outline_rounded, title: 'No booking requests yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: requests.length,
            itemBuilder: (context, index) => _RequestTile(request: requests[index]),
          );
        },
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request});

  final BookingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final guestAsync = ref.watch(userProfileProvider(request.guestId));

    Future<void> respond(BookingStatus status) async {
      await ref.read(bookingRepositoryProvider).updateStatus(requestId: request.id, status: status);
      ref.invalidate(incomingBookingRequestsProvider);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(photoUrl: guestAsync.valueOrNull?.photoUrl, name: guestAsync.valueOrNull?.name, radius: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guestAsync.valueOrNull?.name ?? '...', style: theme.textTheme.titleSmall),
                      Text(
                        '${DateFormat('MMM d').format(request.startDate)} – ${DateFormat('MMM d, y').format(request.endDate)} · ${request.guestsCount} guest(s)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((request.message ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(request.message!, style: theme.textTheme.bodyMedium),
            ],
            if (request.status == BookingStatus.pending) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => respond(BookingStatus.declined),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => respond(BookingStatus.accepted),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  request.status.name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
