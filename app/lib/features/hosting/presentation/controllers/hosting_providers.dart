import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/booking_repository.dart';
import '../../data/booking_request.dart';
import '../../data/host_profile.dart';
import '../../data/host_repository.dart';

final hostRepositoryProvider = Provider<HostRepository>((ref) {
  return HostRepository(ref.watch(supabaseClientProvider));
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(supabaseClientProvider));
});

final hostBrowseCityProvider = StateProvider<String?>((ref) => null);

final hostBrowseProvider = FutureProvider.autoDispose<List<HostProfile>>((ref) async {
  final city = ref.watch(hostBrowseCityProvider);
  final result = await ref.watch(hostRepositoryProvider).browseHosts(city: city);
  return result.when(ok: (hosts) => hosts, err: (_) => []);
});

final hostProfileProvider = FutureProvider.autoDispose.family<HostProfile?, String>((ref, hostId) async {
  final result = await ref.watch(hostRepositoryProvider).getHostProfile(hostId);
  return result.when(ok: (profile) => profile, err: (_) => null);
});

final myHostProfileProvider = FutureProvider.autoDispose<HostProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final result = await ref.watch(hostRepositoryProvider).getHostProfile(userId);
  return result.when(ok: (profile) => profile, err: (_) => null);
});

final hostPhotosProvider = FutureProvider.autoDispose.family<List<HostPhoto>, String>((ref, hostId) async {
  final result = await ref.watch(hostRepositoryProvider).getPhotos(hostId);
  return result.when(ok: (photos) => photos, err: (_) => []);
});

final hostAvailabilityProvider = FutureProvider.autoDispose.family<List<HostAvailability>, String>((ref, hostId) async {
  final result = await ref.watch(hostRepositoryProvider).getAvailability(hostId);
  return result.when(ok: (slots) => slots, err: (_) => []);
});

final myTripsProvider = FutureProvider.autoDispose<List<BookingRequest>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final result = await ref.watch(bookingRepositoryProvider).getMyTrips(userId);
  return result.when(ok: (trips) => trips, err: (_) => []);
});

final incomingBookingRequestsProvider = FutureProvider.autoDispose<List<BookingRequest>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final result = await ref.watch(bookingRepositoryProvider).getIncomingRequests(userId);
  return result.when(ok: (requests) => requests, err: (_) => []);
});
