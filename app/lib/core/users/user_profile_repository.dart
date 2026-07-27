import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/result.dart';
import 'app_user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Result<AppUserProfile>> getProfile(String userId) {
    return guard(() async {
      final row = await _client.from('users').select().eq('id', userId).single();
      return AppUserProfile.fromJson(row);
    });
  }

  Future<Result<List<AppUserProfile>>> getProfiles(List<String> userIds) {
    return guard(() async {
      if (userIds.isEmpty) return <AppUserProfile>[];
      final rows = await _client.from('users').select().inFilter('id', userIds);
      return rows.map(AppUserProfile.fromJson).toList();
    });
  }

  /// Only `name`/`city`/`photo_url`/`bio` are writable by the user — the
  /// `authenticated` role's column grants (see 0002_premium_hosting.sql)
  /// enforce this at the database level too.
  Future<Result<AppUserProfile>> updateProfile({
    required String userId,
    String? name,
    String? city,
    String? photoUrl,
    String? bio,
  }) {
    return guard(() async {
      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (city != null) 'city': city,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (bio != null) 'bio': bio,
      };
      final row = await _client.from('users').update(updates).eq('id', userId).select().single();
      return AppUserProfile.fromJson(row);
    });
  }

  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) {
    return guard(() async {
      final path = '$userId/avatar.$fileExt';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from('avatars').getPublicUrl(path);
    });
  }

  Future<Result<void>> recordProfileView({required String viewedUserId, String? viewerId}) {
    return guard(() async {
      await _client.from('profile_views').insert({
        'viewed_user_id': viewedUserId,
        'viewer_id': viewerId,
      });
    });
  }

  /// Self-service upgrade to the event_planner role — see
  /// `request_event_planner_role` (security definer, only ever moves
  /// 'user' -> 'event_planner') in 0005_roles_and_email_auth.sql.
  Future<Result<void>> requestEventPlannerRole() {
    return guard(() => _client.rpc('request_event_planner_role'));
  }
}
