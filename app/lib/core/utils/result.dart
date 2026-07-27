import 'app_failure.dart';

/// Minimal Result type so repositories never throw across the domain
/// boundary — presentation code pattern-matches instead of try/catching
/// Supabase-specific exceptions everywhere.
sealed class Result<T> {
  const Result();

  factory Result.ok(T value) = Ok<T>;
  factory Result.err(AppFailure failure) = Err<T>;

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) {
    final self = this;
    return switch (self) {
      Ok<T>() => ok(self.value),
      Err<T>() => err(self.failure),
    };
  }

  bool get isOk => this is Ok<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

/// Runs [action], wrapping any thrown error as an [Err] via
/// [AppFailure.fromException] — the standard way repository methods call
/// into Supabase.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } catch (error) {
    return Result.err(AppFailure.fromException(error));
  }
}
