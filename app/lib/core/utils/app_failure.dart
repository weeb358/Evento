import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-facing failure. Repositories translate raw Supabase/Postgrest
/// exceptions into one of these so the presentation layer never has to know
/// about `PostgrestException` etc.
sealed class AppFailure {
  const AppFailure(this.message);

  final String message;

  factory AppFailure.fromException(Object error) {
    if (error is AuthException) {
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

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Not found.']);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}
