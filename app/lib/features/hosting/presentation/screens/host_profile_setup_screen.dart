import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/host_profile.dart';
import '../controllers/hosting_providers.dart';

class HostProfileSetupScreen extends ConsumerStatefulWidget {
  const HostProfileSetupScreen({super.key});

  @override
  ConsumerState<HostProfileSetupScreen> createState() => _HostProfileSetupScreenState();
}

class _HostProfileSetupScreenState extends ConsumerState<HostProfileSetupScreen> {
  final _headlineController = TextEditingController();
  final _aboutController = TextEditingController();
  final _houseRulesController = TextEditingController();
  final _cityController = TextEditingController();
  final _maxGuestsController = TextEditingController(text: '2');

  HomeType _homeType = HomeType.privateRoom;
  latlng.LatLng? _location;
  bool _isSaving = false;
  bool _hasLoadedExisting = false;

  void _loadExisting(HostProfile profile) {
    if (_hasLoadedExisting) return;
    _hasLoadedExisting = true;
    _headlineController.text = profile.headline ?? '';
    _aboutController.text = profile.about ?? '';
    _houseRulesController.text = profile.houseRules ?? '';
    _cityController.text = profile.city ?? '';
    _maxGuestsController.text = profile.maxGuests?.toString() ?? '2';
    _homeType = profile.homeType ?? HomeType.privateRoom;
    if (profile.hasLocation) _location = latlng.LatLng(profile.lat!, profile.lng!);
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _aboutController.dispose();
    _houseRulesController.dispose();
    _cityController.dispose();
    _maxGuestsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSaving = true);

    final result = await ref.read(hostRepositoryProvider).upsertMyProfile(
          userId: userId,
          headline: _headlineController.text.trim(),
          about: _aboutController.text.trim(),
          homeType: _homeType,
          maxGuests: int.tryParse(_maxGuestsController.text.trim()),
          houseRules: _houseRulesController.text.trim(),
          city: _cityController.text.trim(),
          lat: _location?.latitude,
          lng: _location?.longitude,
          isActive: true,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      ok: (_) {
        ref.invalidate(myHostProfileProvider);
        context.go('/hosting/my-listing');
      },
      err: (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final existingAsync = ref.watch(myHostProfileProvider);
    final existing = existingAsync.valueOrNull;
    if (existing != null) _loadExisting(existing);

    return Scaffold(
      appBar: AppBar(title: const Text('Become a host')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell travelers about your place. You can review and accept every request.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _headlineController,
                decoration: const InputDecoration(labelText: 'Headline'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _aboutController,
                decoration: const InputDecoration(labelText: 'About your place'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<HomeType>(
                initialValue: _homeType,
                decoration: const InputDecoration(labelText: 'Home type'),
                items: HomeType.values
                    .map((type) => DropdownMenuItem(value: type, child: Text(homeTypeLabel(type))))
                    .toList(),
                onChanged: (value) => setState(() => _homeType = value ?? _homeType),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _maxGuestsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max guests'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _houseRulesController,
                decoration: const InputDecoration(labelText: 'House rules (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
              const SizedBox(height: AppSpacing.md),
              Text('Tap the map to set your approximate location', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _location ?? const latlng.LatLng(30.3753, 69.3451),
                      initialZoom: _location != null ? 13 : 4.5,
                      onTap: (tapPosition, point) => setState(() => _location = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.eventsplatform.app',
                      ),
                      if (_location != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: _location!,
                            width: 32,
                            height: 32,
                            child: Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 32),
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Publish listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
