import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../../../core/theme/app_spacing.dart';
import '../../data/event.dart';
import '../controllers/event_providers.dart';

class EventsMapScreen extends ConsumerWidget {
  const EventsMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(eventListProvider);
    final events = (eventsAsync.valueOrNull ?? []).where((e) => e.hasLocation).toList();

    final center = events.isNotEmpty
        ? latlng.LatLng(events.first.lat!, events.first.lng!)
        : const latlng.LatLng(30.3753, 69.3451);

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: events.isNotEmpty ? 12 : 4.5),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.eventsplatform.app',
          ),
          MarkerLayer(
            markers: events
                .map(
                  (event) => Marker(
                    point: latlng.LatLng(event.lat!, event.lng!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showEventSheet(context, event),
                      child: Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 36),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showEventSheet(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                event.venueName ?? event.city,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/events/${event.id}');
                  },
                  child: const Text('View event'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
