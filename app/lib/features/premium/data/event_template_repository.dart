import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import '../../events/data/event.dart';
import '../../events/data/event_repository.dart';
import 'event_template.dart';

class EventTemplateRepository {
  EventTemplateRepository(this._client, this._eventRepository);

  final SupabaseClient _client;
  final EventRepository _eventRepository;

  Future<Result<List<EventTemplate>>> getMyTemplates(String organizerId) {
    return guard(() async {
      final rows = await _client
          .from('event_templates')
          .select()
          .eq('organizer_id', organizerId)
          .order('created_at', ascending: false);
      return rows.map(EventTemplate.fromJson).toList();
    });
  }

  Future<Result<EventTemplate>> createTemplate({
    required String organizerId,
    required String title,
    String? description,
    required String category,
    required String city,
    String? venueName,
    required int durationMinutes,
    required double price,
    int? capacity,
    required int intervalWeeks,
    required int count,
    required String timeOfDay,
  }) {
    return guard(() async {
      final row = await _client
          .from('event_templates')
          .insert({
            'organizer_id': organizerId,
            'title': title,
            'description': description,
            'category': category,
            'city': city,
            'venue_name': venueName,
            'duration_minutes': durationMinutes,
            'price': price,
            'capacity': capacity,
            'recurrence_rule': {
              'freq': 'weekly',
              'interval': intervalWeeks,
              'count': count,
              'time': timeOfDay,
            },
          })
          .select()
          .single();
      return EventTemplate.fromJson(row);
    });
  }

  /// Generates the template's weekly occurrences as real `events` rows,
  /// starting from [startingFrom] (defaults to next week).
  Future<Result<List<Event>>> generateEvents(EventTemplate template, {DateTime? startingFrom}) {
    return guard(() async {
      final timeParts = (template.recurrenceRule['time'] as String? ?? '18:00').split(':');
      final hour = int.tryParse(timeParts.first) ?? 18;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

      var next = startingFrom ?? DateTime.now().add(const Duration(days: 7));
      next = DateTime(next.year, next.month, next.day, hour, minute);

      final created = <Event>[];
      for (var i = 0; i < template.occurrenceCount; i++) {
        final startTime = next.add(Duration(days: 7 * template.intervalWeeks * i));
        final endTime = startTime.add(Duration(minutes: template.durationMinutes));

        final result = await _eventRepository.createEvent(
          organizerId: template.organizerId,
          title: template.title,
          description: template.description,
          category: template.category,
          city: template.city,
          venueName: template.venueName,
          lat: template.lat,
          lng: template.lng,
          startTime: startTime,
          endTime: endTime,
          price: template.price,
          capacity: template.capacity,
          coverImageUrl: template.coverImageUrl,
          templateId: template.id,
        );
        result.when(ok: created.add, err: (_) {});
      }
      return created;
    });
  }
}
