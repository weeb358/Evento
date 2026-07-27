import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../controllers/saved_collections_controller.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(collectionEventsProvider(collectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Saved events')),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(icon: Icons.bookmark_outline_rounded, title: 'Nothing saved here yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: events.length,
            itemBuilder: (context, index) => EventCard(event: events[index]),
          );
        },
      ),
    );
  }
}
