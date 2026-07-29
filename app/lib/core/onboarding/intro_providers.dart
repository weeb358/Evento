import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHasSeenIntroKey = 'has_seen_intro';

/// Loaded once in `main.dart` before `runApp` (so the very first router
/// `redirect` call already has the answer) and overridden into
/// [hasSeenIntroProvider] via `ProviderScope(overrides: ...)`. The intro
/// screen flips it after "Get Started" and persists the new value.
Future<bool> loadHasSeenIntro() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kHasSeenIntroKey) ?? false;
}

Future<void> markIntroSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kHasSeenIntroKey, true);
}

final hasSeenIntroProvider = StateProvider<bool>((ref) => false);
