import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/event.dart';
import '../../data/event_filters.dart';
import '../../data/event_repository.dart';
import '../../data/rsvp.dart';
import '../../data/rsvp_repository.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(supabaseClientProvider));
});

final rsvpRepositoryProvider = Provider<RsvpRepository>((ref) {
  return RsvpRepository(ref.watch(supabaseClientProvider));
});

/// Drives the events list screen — re-fetches whenever the filter set
/// changes (city/category/date free for everyone; price/radius/time-window
/// only ever get set when the user is premium, gated in the UI).
final activeFiltersProvider = StateProvider<EventFilters>((ref) => const EventFilters());

final eventListProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final filters = ref.watch(activeFiltersProvider);
  final result = await ref.watch(eventRepositoryProvider).listEvents(filters);
  return result.when(ok: (events) => events, err: (_) => []);
});

final eventDetailProvider = FutureProvider.autoDispose.family<Event?, String>((ref, eventId) async {
  final result = await ref.watch(eventRepositoryProvider).getEvent(eventId);
  return result.when(ok: (event) => event, err: (_) => null);
});

final organizerEventsProvider = FutureProvider.autoDispose.family<List<Event>, String>((ref, organizerId) async {
  final result = await ref.watch(eventRepositoryProvider).getEventsByOrganizer(organizerId);
  return result.when(ok: (events) => events, err: (_) => []);
});

/// The signed-in organizer's own events, for the dashboard — null while
/// signed out (route is guarded, but keeps the provider safe either way).
final myOrganizerEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(organizerEventsProvider(userId).future);
});

final myRsvpProvider = FutureProvider.autoDispose.family<Rsvp?, String>((ref, eventId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final result = await ref.watch(rsvpRepositoryProvider).getMyRsvp(eventId: eventId, userId: userId);
  return result.when(ok: (rsvp) => rsvp, err: (_) => null);
});

final rsvpCountsProvider = FutureProvider.autoDispose.family<RsvpCounts, String>((ref, eventId) async {
  final result = await ref.watch(rsvpRepositoryProvider).getCounts(eventId);
  return result.when(ok: (counts) => counts, err: (_) => (going: 0, interested: 0));
});

final eventAttendeesProvider = FutureProvider.autoDispose.family<List<Rsvp>, String>((ref, eventId) async {
  final result = await ref.watch(rsvpRepositoryProvider).getAttendees(eventId);
  return result.when(ok: (rsvps) => rsvps, err: (_) => []);
});
