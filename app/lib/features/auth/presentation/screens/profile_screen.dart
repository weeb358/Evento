import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/premium/premium_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/app_user_profile.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/error_state.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(failure: AppFailure.fromException(error)),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

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
                        Text(profile.name ?? 'Unnamed', style: theme.textTheme.titleLarge),
                        Text(
                          profile.city ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isPremium || profile.role != UserRole.user) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (isPremium) const _ProfileBadge(label: 'PREMIUM'),
                              if (profile.role == UserRole.eventPlanner)
                                const _ProfileBadge(label: 'EVENT PLANNER'),
                              if (profile.role == UserRole.admin) const _ProfileBadge(label: 'ADMIN'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if ((profile.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(profile.bio!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (!isPremium)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.workspace_premium_rounded, color: theme.colorScheme.primary),
                    title: const Text('Go Premium'),
                    subtitle: const Text('Advanced filters, saved folders, early RSVP & more'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/premium/paywall'),
                  ),
                ),
              if (!profile.canOrganizeEvents)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Become an Event Planner'),
                    subtitle: const Text('Create and manage your own events'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await ref.read(userProfileRepositoryProvider).requestEventPlannerRole();
                      ref.invalidate(currentUserProfileProvider);
                    },
                  ),
                ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.night_shelter_outlined),
                      title: const Text('My host listing'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/hosting/my-listing'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: const Text('Booking requests (as host)'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/hosting/booking-requests'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.card_travel_rounded),
                      title: const Text('My trips'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/hosting/bookings'),
                    ),
                    if (isPremium) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.event_repeat_rounded),
                        title: const Text('Recurring event templates'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/premium/templates'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                },
                child: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
