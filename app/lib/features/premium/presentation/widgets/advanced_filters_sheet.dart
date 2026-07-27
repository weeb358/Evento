import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/premium/premium_gate.dart';
import '../../../../core/premium/premium_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../events/presentation/controllers/event_providers.dart';

void showAdvancedFiltersSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AdvancedFiltersSheet(),
  );
}

class _AdvancedFiltersSheet extends ConsumerStatefulWidget {
  const _AdvancedFiltersSheet();

  @override
  ConsumerState<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends ConsumerState<_AdvancedFiltersSheet> {
  late double _maxPrice;
  late double _radiusKm;
  late bool _radiusEnabled;
  int? _withinNextHours;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(activeFiltersProvider);
    _maxPrice = filters.maxPrice ?? 10000;
    _radiusKm = filters.radiusKm ?? 10;
    _radiusEnabled = filters.radiusKm != null;
    _withinNextHours = filters.withinNextHours;
  }

  Future<void> _enableRadius(bool enabled) async {
    if (!enabled) {
      setState(() => _radiusEnabled = false);
      return;
    }
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      var granted = permission;
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.denied || granted == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed for distance filtering.')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final notifier = ref.read(activeFiltersProvider.notifier);
      notifier.state = notifier.state.copyWith(originLat: position.latitude, originLng: position.longitude);
      setState(() => _radiusEnabled = true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _apply() {
    final notifier = ref.read(activeFiltersProvider.notifier);
    notifier.state = notifier.state.copyWith(
      maxPrice: _maxPrice,
      radiusKm: _radiusEnabled ? _radiusKm : null,
      clearRadius: !_radiusEnabled,
      withinNextHours: _withinNextHours,
      clearWithinNextHours: _withinNextHours == null,
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    final notifier = ref.read(activeFiltersProvider.notifier);
    notifier.state = notifier.state.copyWith(
      clearMaxPrice: true,
      clearRadius: true,
      clearWithinNextHours: true,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Advanced filters', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            PremiumGate(
              featureName: 'Advanced filters',
              description: 'Price range, distance, and time-window filters are a Premium feature.',
              child: isPremium ? _buildControls(theme) : const SizedBox.shrink(),
            ),
            if (isPremium) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _clear, child: const Text('Clear'))),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: FilledButton(onPressed: _apply, child: const Text('Apply'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Max price: Rs ${_maxPrice.toStringAsFixed(0)}', style: theme.textTheme.labelLarge),
        Slider(
          value: _maxPrice,
          min: 0,
          max: 20000,
          divisions: 40,
          onChanged: (value) => setState(() => _maxPrice = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Within a distance of me'),
          value: _radiusEnabled,
          onChanged: _locating ? null : _enableRadius,
        ),
        if (_radiusEnabled) ...[
          Text('Radius: ${_radiusKm.toStringAsFixed(0)} km', style: theme.textTheme.labelLarge),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (value) => setState(() => _radiusKm = value),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text('Starting within', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            _windowChip(null, 'Any time'),
            _windowChip(2, 'Next 2h'),
            _windowChip(6, 'Next 6h'),
            _windowChip(24, 'Next 24h'),
          ],
        ),
      ],
    );
  }

  Widget _windowChip(int? hours, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _withinNextHours == hours,
      onSelected: (_) => setState(() => _withinNextHours = hours),
    );
  }
}
