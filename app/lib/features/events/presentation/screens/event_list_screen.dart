import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../premium/presentation/widgets/advanced_filters_sheet.dart';
import '../../data/event.dart';
import '../controllers/event_providers.dart';
import '../widgets/event_card.dart';

/// Free "near me" radius — the Premium advanced-filters sheet offers a
/// custom slider; this is the one-tap, no-Premium-required default.
const _kNearMeRadiusKm = 30.0;

const _kCities = ['All cities', 'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Peshawar'];

class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  final _searchController = TextEditingController();
  bool _isLocating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleNearMe(bool enable) async {
    final notifier = ref.read(activeFiltersProvider.notifier);

    if (!enable) {
      notifier.state = notifier.state.copyWith(clearRadius: true);
      return;
    }

    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed to show nearby events.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      notifier.state = notifier.state.copyWith(
        originLat: position.latitude,
        originLng: position.longitude,
        radiusKm: _kNearMeRadiusKm,
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(activeFiltersProvider);
    final eventsAsync = ref.watch(eventListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Advanced filters',
            onPressed: () => showAdvancedFiltersSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleCreateTap(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search events',
              ),
              onSubmitted: (value) {
                ref.read(activeFiltersProvider.notifier).state = filters.copyWith(searchQuery: value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                avatar: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Near me'),
                selected: filters.radiusKm != null,
                onSelected: _isLocating ? null : _toggleNearMe,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              scrollDirection: Axis.horizontal,
              itemCount: _kCities.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final city = _kCities[index];
                final isAll = city == 'All cities';
                final isSelected = isAll ? filters.city == null : filters.city == city;
                return ChoiceChip(
                  label: Text(city),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(activeFiltersProvider.notifier).state = filters.copyWith(
                      city: isAll ? null : city,
                      clearCity: isAll,
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: kEventCategories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = filters.category == null;
                  return ChoiceChip(
                    label: const Text('All categories'),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(activeFiltersProvider.notifier).state = filters.copyWith(clearCategory: true);
                    },
                  );
                }
                final category = kEventCategories[index - 1];
                final isSelected = filters.category == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(activeFiltersProvider.notifier).state = filters.copyWith(category: category);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: eventsAsync.when(
              loading: () => const SkeletonList(),
              error: (error, _) => ErrorState(
                failure: AppFailure.fromException(error),
                onRetry: () => ref.invalidate(eventListProvider),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No events found',
                    message: 'Try a different city, category, or search term.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(eventListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: events.length,
                    itemBuilder: (context, index) => EventCard(event: events[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateTap(BuildContext context) async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;

    if (profile == null) {
      context.push('/auth/email-login');
      return;
    }

    if (profile.canOrganizeEvents) {
      context.push('/events/create');
      return;
    }

    final becomeOrganizer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Become an Event Planner'),
        content: const Text('Creating events requires an Event Planner account. Switch now?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Become an Event Planner'),
          ),
        ],
      ),
    );

    if (becomeOrganizer != true) return;

    await ref.read(userProfileRepositoryProvider).requestEventPlannerRole();
    ref.invalidate(currentUserProfileProvider);

    if (context.mounted) context.push('/events/create');
  }
}
