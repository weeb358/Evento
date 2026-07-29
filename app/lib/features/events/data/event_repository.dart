import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import 'event.dart';
import 'event_filters.dart';

class EventRepository {
  EventRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<Event>>> listEvents(EventFilters filters, {int limit = 30, int offset = 0}) {
    return guard(() async {
      var query = _client.from('events').select().eq('status', 'published');

      if (filters.city != null) query = query.eq('city', filters.city!);
      if (filters.category != null) query = query.eq('category', filters.category!);
      if (filters.dateFrom != null) query = query.gte('start_time', filters.dateFrom!.toIso8601String());
      if (filters.dateTo != null) query = query.lte('start_time', filters.dateTo!.toIso8601String());
      if (filters.maxPrice != null) query = query.lte('price', filters.maxPrice!);
      if (filters.withinNextHours != null) {
        final until = DateTime.now().add(Duration(hours: filters.withinNextHours!));
        query = query.lte('start_time', until.toIso8601String());
        query = query.gte('start_time', DateTime.now().toIso8601String());
      }
      if ((filters.searchQuery ?? '').trim().isNotEmpty) {
        query = query.textSearch('search_vector', filters.searchQuery!.trim());
      }

      final rows = await query
          .order('is_featured', ascending: false)
          .order('start_time', ascending: true)
          .range(offset, offset + limit - 1);

      var events = rows.map(Event.fromJson).toList();

      // No PostGIS in this schema — a radius filter is a small client-side
      // pass over the already-narrowed page rather than a spatial query.
      if (filters.radiusKm != null && filters.originLat != null && filters.originLng != null) {
        events = events.where((event) {
          if (!event.hasLocation) return false;
          final distanceMeters = _haversineMeters(
            filters.originLat!,
            filters.originLng!,
            event.lat!,
            event.lng!,
          );
          return distanceMeters / 1000 <= filters.radiusKm!;
        }).toList();
      }

      return events;
    });
  }

  Future<Result<Event>> getEvent(String id) {
    return guard(() async {
      final row = await _client.from('events').select().eq('id', id).single();
      return Event.fromJson(row);
    });
  }

  Future<Result<List<Event>>> getEventsByIds(List<String> ids) {
    return guard(() async {
      if (ids.isEmpty) return <Event>[];
      final rows = await _client.from('events').select().inFilter('id', ids);
      return rows.map(Event.fromJson).toList();
    });
  }

  Future<Result<List<Event>>> getEventsByOrganizer(String organizerId) {
    return guard(() async {
      final rows = await _client
          .from('events')
          .select()
          .eq('organizer_id', organizerId)
          .order('start_time', ascending: false);
      return rows.map(Event.fromJson).toList();
    });
  }

  Future<Result<Event>> createEvent({
    required String organizerId,
    required String title,
    String? description,
    required String category,
    required String city,
    String? venueName,
    double? lat,
    double? lng,
    required DateTime startTime,
    DateTime? endTime,
    required double price,
    int? capacity,
    String? coverImageUrl,
    bool isFeatured = false,
    DateTime? premiumRsvpOpensAt,
    String? templateId,
  }) {
    return guard(() async {
      final row = await _client
          .from('events')
          .insert({
            'organizer_id': organizerId,
            'title': title,
            'description': description,
            'category': category,
            'city': city,
            'venue_name': venueName,
            'lat': lat,
            'lng': lng,
            'start_time': startTime.toIso8601String(),
            'end_time': endTime?.toIso8601String(),
            'price': price,
            'capacity': capacity,
            'cover_image_url': coverImageUrl,
            'is_featured': isFeatured,
            'premium_rsvp_opens_at': premiumRsvpOpensAt?.toIso8601String(),
            'template_id': templateId,
          })
          .select()
          .single();
      return Event.fromJson(row);
    });
  }

  Future<Result<Event>> updateEvent({
    required String id,
    String? title,
    String? description,
    String? category,
    String? city,
    String? venueName,
    double? lat,
    double? lng,
    DateTime? startTime,
    DateTime? endTime,
    double? price,
    int? capacity,
    String? coverImageUrl,
    EventStatus? status,
    bool? isFeatured,
  }) {
    return guard(() async {
      final updates = <String, dynamic>{
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (city != null) 'city': city,
        if (venueName != null) 'venue_name': venueName,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (startTime != null) 'start_time': startTime.toIso8601String(),
        if (endTime != null) 'end_time': endTime.toIso8601String(),
        if (price != null) 'price': price,
        if (capacity != null) 'capacity': capacity,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (status != null) 'status': status.name,
        if (isFeatured != null) 'is_featured': isFeatured,
      };
      final row = await _client.from('events').update(updates).eq('id', id).select().single();
      return Event.fromJson(row);
    });
  }

  Future<Result<void>> deleteEvent(String id) {
    return guard(() => _client.from('events').delete().eq('id', id));
  }

  /// Copies an existing event into a new draft owned by [organizerId] —
  /// pushed a week out from the original start time so it never lands in
  /// the past, left as a draft so the organizer reviews it before publishing.
  Future<Result<Event>> duplicateEvent({required String sourceId, required String organizerId}) {
    return guard(() async {
      final source = await _client.from('events').select().eq('id', sourceId).single();
      final sourceEvent = Event.fromJson(source);
      final newStart = sourceEvent.startTime.add(const Duration(days: 7));
      final newEnd = sourceEvent.endTime?.add(const Duration(days: 7));

      final row = await _client
          .from('events')
          .insert({
            'organizer_id': organizerId,
            'title': '${sourceEvent.title} (Copy)',
            'description': sourceEvent.description,
            'category': sourceEvent.category,
            'city': sourceEvent.city,
            'venue_name': sourceEvent.venueName,
            'lat': sourceEvent.lat,
            'lng': sourceEvent.lng,
            'start_time': newStart.toIso8601String(),
            'end_time': newEnd?.toIso8601String(),
            'price': sourceEvent.price,
            'capacity': sourceEvent.capacity,
            'cover_image_url': sourceEvent.coverImageUrl,
            'status': EventStatus.draft.name,
            'is_featured': false,
          })
          .select()
          .single();
      return Event.fromJson(row);
    });
  }

  Future<Result<String>> uploadCoverImage({
    required String organizerId,
    required Uint8List bytes,
    required String fileExt,
  }) {
    return guard(() async {
      final path = '$organizerId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _client.storage.from('event-covers').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from('event-covers').getPublicUrl(path);
    });
  }

  Future<Result<void>> recordView({required String eventId, String? viewerId}) {
    return guard(() async {
      await _client.from('event_views').insert({'event_id': eventId, 'viewer_id': viewerId});
    });
  }
}

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degToRad(double deg) => deg * (pi / 180);
