import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';

typedef DailyCount = ({DateTime day, int count});

class EventAnalytics {
  const EventAnalytics({
    required this.totalViews,
    required this.goingCount,
    required this.interestedCount,
    required this.viewsByDay,
  });

  final int totalViews;
  final int goingCount;
  final int interestedCount;
  final List<DailyCount> viewsByDay;
}

class AnalyticsRepository {
  AnalyticsRepository(this._client);

  final SupabaseClient _client;

  /// Organizer-only — RLS on `event_views` only returns rows to the
  /// event's organizer (see 0002_premium_hosting.sql).
  Future<Result<EventAnalytics>> getEventAnalytics(String eventId) {
    return guard(() async {
      final views = await _client
          .from('event_views')
          .select('created_at')
          .eq('event_id', eventId)
          .order('created_at');

      final rsvps = await _client.from('event_rsvps').select('status').eq('event_id', eventId);

      final byDay = <DateTime, int>{};
      for (final row in views) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        byDay[day] = (byDay[day] ?? 0) + 1;
      }
      final viewsByDay = byDay.entries.map((e) => (day: e.key, count: e.value)).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

      final goingCount = rsvps.where((r) => r['status'] == 'going').length;
      final interestedCount = rsvps.where((r) => r['status'] == 'interested').length;

      return EventAnalytics(
        totalViews: views.length,
        goingCount: goingCount,
        interestedCount: interestedCount,
        viewsByDay: viewsByDay,
      );
    });
  }
}
