import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../users/user_profile_providers.dart';

/// The single `isPremium` check every gated feature should read — never
/// re-derive premium status ad hoc from `currentUserProfileProvider`
/// directly. Defaults to false while the profile is loading/unavailable, so
/// gated UI fails closed rather than briefly flashing premium content.
final isPremiumProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  return profile?.isPremium ?? false;
});
