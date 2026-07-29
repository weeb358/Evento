import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_failure.dart';
import '../../../core/utils/result.dart';

class AuthRepository {
  AuthRepository(this._client, {required String googleWebClientId})
      : _googleSignIn = GoogleSignIn(serverClientId: googleWebClientId);

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  /// [requestEventPlanner] is honored server-side only as a literal
  /// 'event_planner' request — see handle_new_auth_user() in
  /// 0005_roles_and_email_auth.sql; there's no way to request 'admin' here.
  /// Doesn't sign the user in yet — Supabase requires the code from
  /// [verifySignUpCode] first (see docs/ARCHITECTURE.md re: the email OTP
  /// template needing custom SMTP to actually deliver a code).
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

  /// Completes signup with the 6-digit code from the confirmation email —
  /// the counterpart to [signUpWithEmail]. Establishes a session on success.
  Future<Result<void>> verifySignUpCode({required String email, required String token}) {
    return guard(() async {
      await _client.auth.verifyOTP(email: email, token: token, type: OtpType.signup);
    });
  }

  Future<Result<void>> resendSignUpCode(String email) {
    return guard(() => _client.auth.resend(type: OtpType.signup, email: email));
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

  /// Native Google Sign-In → Supabase's ID-token exchange. Requires
  /// GOOGLE_WEB_CLIENT_ID (a Google Cloud OAuth **Web** client, not the
  /// Android one — Supabase's id-token flow specifically needs the Web
  /// client's audience) and the Google provider enabled in Supabase Auth.
  /// See docs/ARCHITECTURE.md for the exact setup steps.
  Future<Result<void>> signInWithGoogle() {
    return guard(() async {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker — not an error, just no-op via a
        // sentinel the caller can treat as "cancelled".
        throw const AuthFailure('Sign-in cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) {
        throw const AuthFailure('Google sign-in did not return an ID token.');
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    });
  }

  Future<Result<void>> signOut() {
    return guard(() async {
      await _googleSignIn.signOut();
      await _client.auth.signOut();
    });
  }
}
