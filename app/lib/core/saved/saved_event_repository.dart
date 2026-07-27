import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';
import '../utils/result.dart';
import 'saved_collection.dart';

class SavedEventRepository {
  SavedEventRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<SavedCollection>>> getMyCollections(String userId) {
    return guard(() async {
      final rows = await _client
          .from('saved_collections')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      return rows.map(SavedCollection.fromJson).toList();
    });
  }

  /// Premium-only — Standard users only ever have their auto-created
  /// default collection (see 0002_premium_hosting.sql trigger). [isPremium]
  /// is passed in from the caller's `isPremiumProvider` read rather than
  /// re-derived here, so this repository stays free of auth/session state.
  Future<Result<SavedCollection>> createCollection({
    required String userId,
    required String name,
    required bool isPremium,
  }) {
    if (!isPremium) {
      return Future.value(
        Result<SavedCollection>.err(
          const ValidationFailure('Custom folders are a Premium feature.'),
        ),
      );
    }
    return guard(() async {
      final row = await _client
          .from('saved_collections')
          .insert({'user_id': userId, 'name': name})
          .select()
          .single();
      return SavedCollection.fromJson(row);
    });
  }

  Future<Result<Set<String>>> getSavedEventIds(String userId) {
    return guard(() async {
      final collections = await _client.from('saved_collections').select('id').eq('user_id', userId);
      final collectionIds = collections.map((c) => c['id'] as String).toList();
      if (collectionIds.isEmpty) return <String>{};

      final rows = await _client.from('saved_events').select('event_id').inFilter(
            'collection_id',
            collectionIds,
          );
      return rows.map((r) => r['event_id'] as String).toSet();
    });
  }

  Future<Result<Set<String>>> getEventIdsInCollection(String collectionId) {
    return guard(() async {
      final rows = await _client.from('saved_events').select('event_id').eq('collection_id', collectionId);
      return rows.map((r) => r['event_id'] as String).toSet();
    });
  }

  /// Toggles [eventId] in the user's default ("Saved") collection — the
  /// quick bookmark action available from an event card/detail screen.
  Future<Result<bool>> toggleDefaultBookmark({required String userId, required String eventId}) {
    return guard(() async {
      final defaultCollection = await _client
          .from('saved_collections')
          .select('id')
          .eq('user_id', userId)
          .eq('is_default', true)
          .single();
      final collectionId = defaultCollection['id'] as String;

      final existing = await _client
          .from('saved_events')
          .select('id')
          .eq('collection_id', collectionId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('saved_events').insert({
          'collection_id': collectionId,
          'event_id': eventId,
        });
        return true;
      } else {
        await _client.from('saved_events').delete().eq('id', existing['id'] as String);
        return false;
      }
    });
  }

  Future<Result<void>> addEventToCollection({required String collectionId, required String eventId}) {
    return guard(() async {
      await _client.from('saved_events').upsert(
        {'collection_id': collectionId, 'event_id': eventId},
        onConflict: 'collection_id,event_id',
      );
    });
  }

  Future<Result<void>> removeEventFromCollection({required String collectionId, required String eventId}) {
    return guard(() async {
      await _client
          .from('saved_events')
          .delete()
          .eq('collection_id', collectionId)
          .eq('event_id', eventId);
    });
  }
}
