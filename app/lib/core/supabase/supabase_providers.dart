import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single Supabase client instance, initialized in `main.dart` before
/// `runApp`. All feature repositories should read this instead of calling
/// `Supabase.instance.client` directly, so tests can override it.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits the current auth state (signed in / signed out / token refreshed)
/// so features can react without each wiring its own listener.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The current user's id, or null if signed out. Convenience over
/// `authStateChangesProvider` for widgets that only need the id.
final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateChangesProvider);
  return client.auth.currentUser?.id;
});
