import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'app_user_profile.dart';
import 'user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's own profile row. Null while signed out. Refetches
/// whenever auth state or the id changes; callers that mutate the profile
/// should `ref.invalidate(currentUserProfileProvider)` afterwards.
final currentUserProfileProvider = FutureProvider<AppUserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final result = await ref.watch(userProfileRepositoryProvider).getProfile(userId);
  return result.when(ok: (profile) => profile, err: (_) => null);
});

/// Any user's public profile by id (organizer, reviewer, host, guest, ...).
final userProfileProvider = FutureProvider.family<AppUserProfile?, String>((ref, userId) async {
  final result = await ref.watch(userProfileRepositoryProvider).getProfile(userId);
  return result.when(ok: (profile) => profile, err: (_) => null);
});
