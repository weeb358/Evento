import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/saved/saved_event_providers.dart';
import '../../../events/data/event.dart';
import '../../../events/presentation/controllers/event_providers.dart';

/// Fetches the saved-event ids for a collection, then the matching events —
/// combined into one provider so screens don't juggle two async states.
final collectionEventsProvider = FutureProvider.autoDispose.family<List<Event>, String>((ref, collectionId) async {
  final ids = await ref.watch(eventIdsInCollectionProvider(collectionId).future);
  final result = await ref.watch(eventRepositoryProvider).getEventsByIds(ids.toList());
  return result.when(ok: (events) => events, err: (_) => []);
});
