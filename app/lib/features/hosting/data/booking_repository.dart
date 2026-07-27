import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import 'booking_request.dart';

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<BookingRequest>>> getMyTrips(String guestId) {
    return guard(() async {
      final rows = await _client
          .from('booking_requests')
          .select()
          .eq('guest_id', guestId)
          .order('start_date', ascending: false);
      return rows.map(BookingRequest.fromJson).toList();
    });
  }

  Future<Result<List<BookingRequest>>> getIncomingRequests(String hostId) {
    return guard(() async {
      final rows = await _client
          .from('booking_requests')
          .select()
          .eq('host_id', hostId)
          .order('created_at', ascending: false);
      return rows.map(BookingRequest.fromJson).toList();
    });
  }

  Future<Result<BookingRequest>> createRequest({
    required String hostId,
    required String guestId,
    required DateTime startDate,
    required DateTime endDate,
    required int guestsCount,
    String? message,
  }) {
    return guard(() async {
      final row = await _client
          .from('booking_requests')
          .insert({
            'host_id': hostId,
            'guest_id': guestId,
            'start_date': _dateOnly(startDate),
            'end_date': _dateOnly(endDate),
            'guests_count': guestsCount,
            'message': message,
          })
          .select()
          .single();
      return BookingRequest.fromJson(row);
    });
  }

  Future<Result<void>> updateStatus({required String requestId, required BookingStatus status}) {
    return guard(() async {
      await _client.from('booking_requests').update({'status': status.name}).eq('id', requestId);
    });
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
