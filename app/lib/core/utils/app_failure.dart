import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-facing failure. Repositories translate raw Supabase/Postgrest
/// exceptions into one of these so the presentation layer never has to know
/// about `PostgrestException` etc.
sealed class AppFailure {
  const AppFailure(this.message);

  final String message;

  factory AppFailure.fromException(Object error) {
    // A repository may preemptively throw a specific AppFailure (e.g. a
    // "cancelled" case that isn't really an error) inside `guard()` —
    // pass it through unchanged instead of falling into UnknownFailure.
    if (error is AppFailure) return error;
    if (error is AuthException) {
      if (error.code == 'email_not_confirmed') {
        return const EmailNotConfirmedFailure();
      }
      return AuthFailure(error.message);
    }
    if (error is PostgrestException) {
      // Unique-violation / RLS-denied read as "not allowed" rather than a
      // raw Postgres error code, since they're the two cases a user can hit.
      if (error.code == '23505') {
        return const ValidationFailure('That already exists.');
      }
      return NetworkFailure(error.message);
    }
    if (error is StorageException) {
      return NetworkFailure(error.message);
    }
    return UnknownFailure(error.toString());
  }
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// Distinguished from [AuthFailure] so the login screen can route to the
/// verify-code screen instead of the generic "wrong email/password" prompt —
/// this is what a user with an unfinished signup (or one whose account was
/// stuck before custom SMTP was configured) actually hits.
final class EmailNotConfirmedFailure extends AppFailure {
  const EmailNotConfirmedFailure() : super('Please confirm your email first.');
}

/// Thrown by [AuthRepository.signInWithGoogle] when called with
/// `allowSignUp: false` (the login screen) and the Google account has no
/// existing app account yet — mirrors the email flow's "sign up first"
/// prompt instead of silently creating an account from the login screen.
final class GoogleAccountNotRegisteredFailure extends AppFailure {
  const GoogleAccountNotRegisteredFailure() : super('No account found for that Google sign-in.');
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Not found.']);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}
