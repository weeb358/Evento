import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/utils/app_failure.dart';
import '../../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(supabaseClientProvider),
    googleWebClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '',
  );
});

/// Drives the email login/signup/forgot-password/verify-code screens.
/// `AsyncValue.error` carries an [AppFailure] (not a raw exception) so
/// screens can show `failure.message` directly.
class EmailAuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signUp({
    required String email,
    required String password,
    bool requestEventPlanner = false,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signUpWithEmail(
          email: email,
          password: password,
          requestEventPlanner: requestEventPlanner,
        );
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> verifySignUpCode({required String email, required String token}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).verifySignUpCode(email: email, token: token);
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> resendSignUpCode(String email) async {
    final result = await ref.read(authRepositoryProvider).resendSignUpCode(email);
    return result.isOk;
  }

  /// Returns false both when the account doesn't exist and when the
  /// password is wrong — see the comment on
  /// AuthRepository.signInWithEmail for why those can't be told apart.
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signInWithEmail(email: email, password: password);
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> signInWithGoogle({bool allowSignUp = true}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signInWithGoogle(allowSignUp: allowSignUp);
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> sendPasswordReset(String email, {required String redirectTo}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(email, redirectTo: redirectTo);
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  AppFailure? get failure {
    final value = state;
    return value is AsyncError ? value.error as AppFailure : null;
  }

  String? get errorMessage => failure?.message;

  /// Resets to idle without touching the session — for screens to call on
  /// entry so a failure from a previous screen (this notifier is shared
  /// app-wide) doesn't show up as if it just happened here.
  void clearError() {
    if (state is AsyncError) state = const AsyncData(null);
  }
}

final emailAuthControllerProvider = AsyncNotifierProvider<EmailAuthController, void>(EmailAuthController.new);
