import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/host_profile.dart';
import '../controllers/hosting_providers.dart';

class MyHostListingScreen extends ConsumerWidget {
  const MyHostListingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(myHostProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My listing'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/hosting/setup')),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (profile) {
          if (profile == null) {
            return EmptyState(
              icon: Icons.night_shelter_outlined,
              title: 'You\'re not hosting yet',
              action: FilledButton(
                onPressed: () => context.push('/hosting/setup'),
                child: const Text('Become a host'),
              ),
            );
          }

          final photosAsync = ref.watch(hostPhotosProvider(profile.id));
          final availabilityAsync = ref.watch(hostAvailabilityProvider(profile.id));

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Listing is visible'),
                subtitle: Text(
                  profile.verificationStatus.name == 'verified' ? 'Verified host' : 'Verification: ${profile.verificationStatus.name}',
                ),
                value: profile.isActive,
                onChanged: (value) async {
                  final userId = ref.read(currentUserIdProvider);
                  if (userId == null) return;
                  await ref.read(hostRepositoryProvider).upsertMyProfile(userId: userId, isActive: value);
                  ref.invalidate(myHostProfileProvider);
                },
              ),
              if (profile.verificationStatus == HostVerificationStatus.unverified)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Request verification'),
                    onPressed: () async {
                      await ref.read(hostRepositoryProvider).requestVerification();
                      ref.invalidate(myHostProfileProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification requested — an admin will review it.')),
                        );
                      }
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Photos', style: theme.textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo_outlined),
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      final currentCount = photosAsync.valueOrNull?.length ?? 0;
                      await ref.read(hostRepositoryProvider).uploadAndAddPhoto(
                            hostId: profile.id,
                            bytes: bytes,
                            fileExt: picked.name.split('.').last,
                            sortOrder: currentCount,
                          );
                      ref.invalidate(hostPhotosProvider(profile.id));
                    },
                  ),
                ],
              ),
              photosAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (photos) => SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            child: Image.network(photo.url, width: 90, height: 90, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.white),
                              onPressed: () async {
                                await ref.read(hostRepositoryProvider).removePhoto(photo.id);
                                ref.invalidate(hostPhotosProvider(profile.id));
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Availability', style: theme.textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _addAvailability(context, ref, profile.id),
                  ),
                ],
              ),
              availabilityAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (slots) {
                  if (slots.isEmpty) {
                    return Text(
                      'No open dates yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    );
                  }
                  return Column(
                    children: slots
                        .map(
                          (slot) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${DateFormat('MMM d').format(slot.startDate)} – ${DateFormat('MMM d, y').format(slot.endDate)}',
                            ),
                            subtitle: slot.note != null ? Text(slot.note!) : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                await ref.read(hostRepositoryProvider).removeAvailability(slot.id);
                                ref.invalidate(hostAvailabilityProvider(profile.id));
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addAvailability(BuildContext context, WidgetRef ref, String hostId) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;
    await ref.read(hostRepositoryProvider).addAvailability(
          hostId: hostId,
          startDate: range.start,
          endDate: range.end,
        );
    ref.invalidate(hostAvailabilityProvider(hostId));
  }
}
