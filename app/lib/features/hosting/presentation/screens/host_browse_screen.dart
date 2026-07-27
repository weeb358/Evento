import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../controllers/hosting_providers.dart';
import '../../data/host_profile.dart';

const _kHostCities = ['All cities', 'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Peshawar'];

class HostBrowseScreen extends ConsumerWidget {
  const HostBrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(hostBrowseProvider);
    final selectedCity = ref.watch(hostBrowseCityProvider);
    final myHostProfileAsync = ref.watch(myHostProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hosting'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(
              myHostProfileAsync.valueOrNull != null ? '/hosting/my-listing' : '/hosting/setup',
            ),
            icon: const Icon(Icons.add_home_outlined),
            label: const Text('Host'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              scrollDirection: Axis.horizontal,
              itemCount: _kHostCities.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final city = _kHostCities[index];
                final isAll = city == 'All cities';
                final isSelected = isAll ? selectedCity == null : selectedCity == city;
                return ChoiceChip(
                  label: Text(city),
                  selected: isSelected,
                  onSelected: (_) => ref.read(hostBrowseCityProvider.notifier).state = isAll ? null : city,
                );
              },
            ),
          ),
          Expanded(
            child: hostsAsync.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load hosts'),
              data: (hosts) {
                if (hosts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.night_shelter_outlined,
                    title: 'No hosts yet',
                    message: 'Be the first to open your home to travelers.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: hosts.length,
                  itemBuilder: (context, index) => _HostTile(host: hosts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HostTile extends ConsumerWidget {
  const _HostTile({required this.host});

  final HostProfile host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider(host.id));

    return Card(
      child: ListTile(
        onTap: () => context.push('/hosting/${host.id}'),
        leading: AppAvatar(photoUrl: profileAsync.valueOrNull?.photoUrl, name: profileAsync.valueOrNull?.name, radius: 24),
        title: Row(
          children: [
            Flexible(child: Text(profileAsync.valueOrNull?.name ?? '...', overflow: TextOverflow.ellipsis)),
            if (host.isVerified) ...[
              const SizedBox(width: 4),
              Icon(Icons.verified_rounded, size: 16, color: theme.colorScheme.primary),
            ],
          ],
        ),
        subtitle: Text(
          [host.headline, host.city].where((s) => (s ?? '').isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
