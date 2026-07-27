import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import 'host_profile.dart';

class HostPhoto {
  const HostPhoto({required this.id, required this.hostId, required this.url, required this.sortOrder});

  final String id;
  final String hostId;
  final String url;
  final int sortOrder;

  factory HostPhoto.fromJson(Map<String, dynamic> json) {
    return HostPhoto(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      url: json['url'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class HostAvailability {
  const HostAvailability({required this.id, required this.hostId, required this.startDate, required this.endDate, this.note});

  final String id;
  final String hostId;
  final DateTime startDate;
  final DateTime endDate;
  final String? note;

  factory HostAvailability.fromJson(Map<String, dynamic> json) {
    return HostAvailability(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      note: json['note'] as String?,
    );
  }
}

class HostRepository {
  HostRepository(this._client);

  final SupabaseClient _client;

  /// Moves the caller's own listing to `pending` review — hosts can request
  /// verification but never self-approve; see `request_host_verification`
  /// (security definer) and the column-privilege revoke in
  /// 0004_admin_rls.sql for why this can't just be a normal update.
  Future<Result<void>> requestVerification() {
    return guard(() => _client.rpc('request_host_verification'));
  }

  Future<Result<HostProfile?>> getHostProfile(String hostId) {
    return guard(() async {
      final row = await _client.from('host_profiles').select().eq('id', hostId).maybeSingle();
      return row == null ? null : HostProfile.fromJson(row);
    });
  }

  Future<Result<List<HostProfile>>> browseHosts({String? city}) {
    return guard(() async {
      var query = _client.from('host_profiles').select().eq('is_active', true);
      if (city != null) query = query.eq('city', city);
      final rows = await query.order('created_at', ascending: false);
      return rows.map(HostProfile.fromJson).toList();
    });
  }

  Future<Result<HostProfile>> upsertMyProfile({
    required String userId,
    String? headline,
    String? about,
    HomeType? homeType,
    int? maxGuests,
    String? houseRules,
    String? city,
    double? lat,
    double? lng,
    bool? isActive,
  }) {
    return guard(() async {
      final row = await _client
          .from('host_profiles')
          .upsert({
            'id': userId,
            if (headline != null) 'headline': headline,
            if (about != null) 'about': about,
            if (homeType != null) 'home_type': homeTypeToString(homeType),
            if (maxGuests != null) 'max_guests': maxGuests,
            if (houseRules != null) 'house_rules': houseRules,
            if (city != null) 'city': city,
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
            if (isActive != null) 'is_active': isActive,
          })
          .select()
          .single();
      return HostProfile.fromJson(row);
    });
  }

  Future<Result<List<HostPhoto>>> getPhotos(String hostId) {
    return guard(() async {
      final rows = await _client.from('host_photos').select().eq('host_id', hostId).order('sort_order');
      return rows.map(HostPhoto.fromJson).toList();
    });
  }

  Future<Result<String>> uploadAndAddPhoto({
    required String hostId,
    required Uint8List bytes,
    required String fileExt,
    required int sortOrder,
  }) {
    return guard(() async {
      final path = '$hostId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _client.storage.from('host-photos').uploadBinary(path, bytes);
      final url = _client.storage.from('host-photos').getPublicUrl(path);
      await _client.from('host_photos').insert({'host_id': hostId, 'url': url, 'sort_order': sortOrder});
      return url;
    });
  }

  Future<Result<void>> removePhoto(String photoId) {
    return guard(() => _client.from('host_photos').delete().eq('id', photoId));
  }

  Future<Result<List<HostAvailability>>> getAvailability(String hostId) {
    return guard(() async {
      final rows = await _client
          .from('host_availability')
          .select()
          .eq('host_id', hostId)
          .order('start_date');
      return rows.map(HostAvailability.fromJson).toList();
    });
  }

  Future<Result<void>> addAvailability({
    required String hostId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  }) {
    return guard(() async {
      await _client.from('host_availability').insert({
        'host_id': hostId,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'note': note,
      });
    });
  }

  Future<Result<void>> removeAvailability(String id) {
    return guard(() => _client.from('host_availability').delete().eq('id', id));
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
