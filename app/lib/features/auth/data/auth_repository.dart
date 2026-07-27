import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Sends a 6-digit OTP to [phone] (E.164 format, e.g. `+923001234567`).
  Future<Result<void>> sendOtp(String phone) {
    return guard(() => _client.auth.signInWithOtp(phone: phone));
  }

  Future<Result<void>> verifyOtp({required String phone, required String token}) {
    return guard(() async {
      await _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
    });
  }

  /// [requestEventPlanner] is honored server-side only as a literal
  /// 'event_planner' request — see handle_new_auth_user() in
  /// 0005_roles_and_email_auth.sql; there's no way to request 'admin' here.
  Future<Result<void>> signUpWithEmail({
    required String email,
    required String password,
    bool requestEventPlanner = false,
  }) {
    return guard(() async {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: requestEventPlanner ? {'requested_role': 'event_planner'} : null,
      );
    });
  }

  /// Supabase deliberately returns the same "Invalid login credentials"
  /// error whether the email doesn't exist or the password is wrong (so a
  /// login form can't be used to enumerate registered emails) — the caller
  /// can't distinguish "no account" from "wrong password" from this error
  /// alone. The UI shows a single "sign in failed — new here? Sign up"
  /// prompt either way, which is what was asked for and doesn't require
  /// leaking which case it was.
  Future<Result<void>> signInWithEmail({required String email, required String password}) {
    return guard(() => _client.auth.signInWithPassword(email: email, password: password));
  }

  /// [redirectTo] should point at a page that can complete the reset (the
  /// website's /auth/reset-password — see docs/ARCHITECTURE.md for why the
  /// app itself doesn't handle the reset link via a native deep link).
  Future<Result<void>> sendPasswordResetEmail(String email, {required String redirectTo}) {
    return guard(() => _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo));
  }

  Future<Result<void>> signOut() {
    return guard(() => _client.auth.signOut());
  }
}
