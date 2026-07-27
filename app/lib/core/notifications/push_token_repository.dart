import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/result.dart';

class PushTokenRepository {
  PushTokenRepository(this._client);

  final SupabaseClient _client;

  /// Upserts by [token] (not by user) — the same physical device can end up
  /// registering a token that used to belong to a different signed-out
  /// user, so re-registering must reassign ownership, not just insert.
  Future<Result<void>> registerToken({required String userId, required String token}) {
    return guard(() async {
      await _client.from('push_tokens').upsert(
        {'user_id': userId, 'token': token, 'platform': 'android'},
        onConflict: 'token',
      );
    });
  }

  Future<Result<void>> deleteToken(String token) {
    return guard(() => _client.from('push_tokens').delete().eq('token', token));
  }
}
