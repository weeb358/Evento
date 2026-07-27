import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import 'rsvp.dart';

typedef RsvpCounts = ({int going, int interested});

class RsvpRepository {
  RsvpRepository(this._client);

  final SupabaseClient _client;

  Future<Result<Rsvp?>> getMyRsvp({required String eventId, required String userId}) {
    return guard(() async {
      final row = await _client
          .from('event_rsvps')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : Rsvp.fromJson(row);
    });
  }

  Future<Result<Rsvp>> setRsvp({
    required String eventId,
    required String userId,
    required RsvpStatus status,
  }) {
    return guard(() async {
      final row = await _client
          .from('event_rsvps')
          .upsert(
            {'event_id': eventId, 'user_id': userId, 'status': status.name},
            onConflict: 'event_id,user_id',
          )
          .select()
          .single();
      return Rsvp.fromJson(row);
    });
  }

  Future<Result<void>> removeRsvp({required String eventId, required String userId}) {
    return guard(() async {
      await _client.from('event_rsvps').delete().eq('event_id', eventId).eq('user_id', userId);
    });
  }

  /// Public aggregate counts via the `get_event_rsvp_counts` RPC — see
  /// 0003_event_rsvp_counts.sql for why this can't just be a row count.
  Future<Result<RsvpCounts>> getCounts(String eventId) {
    return guard(() async {
      final rows = await _client.rpc('get_event_rsvp_counts', params: {'p_event_id': eventId});
      final row = (rows as List).first as Map<String, dynamic>;
      return (
        going: (row['going_count'] as num).toInt(),
        interested: (row['interested_count'] as num).toInt(),
      );
    });
  }

  /// The attendee list itself — RLS only returns rows to the organizer, or
  /// to a premium user who already has their own RSVP (see
  /// rsvps_select_own_organizer_or_premium_attendee in 0002). A non-premium
  /// caller with no RSVP yet will just get an empty list back.
  Future<Result<List<Rsvp>>> getAttendees(String eventId) {
    return guard(() async {
      final rows = await _client
          .from('event_rsvps')
          .select()
          .eq('event_id', eventId)
          .order('created_at');
      return rows.map(Rsvp.fromJson).toList();
    });
  }
}
