import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'saved_collection.dart';
import 'saved_event_repository.dart';

final savedEventRepositoryProvider = Provider<SavedEventRepository>((ref) {
  return SavedEventRepository(ref.watch(supabaseClientProvider));
});

final myCollectionsProvider = FutureProvider<List<SavedCollection>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final result = await ref.watch(savedEventRepositoryProvider).getMyCollections(userId);
  return result.when(ok: (collections) => collections, err: (_) => []);
});

final savedEventIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final result = await ref.watch(savedEventRepositoryProvider).getSavedEventIds(userId);
  return result.when(ok: (ids) => ids, err: (_) => {});
});

final eventIdsInCollectionProvider = FutureProvider.family<Set<String>, String>((ref, collectionId) async {
  final result = await ref.watch(savedEventRepositoryProvider).getEventIdsInCollection(collectionId);
  return result.when(ok: (ids) => ids, err: (_) => {});
});
