import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/result.dart';

class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  /// [targetType] is `'event'` or `'user'` (matches `report_target_type` in
  /// the DB) — reporting a host is just reporting their user id.
  Future<Result<void>> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  }) {
    return guard(() async {
      await _client.from('reports').insert({
        'reporter_id': reporterId,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
      });
    });
  }
}
