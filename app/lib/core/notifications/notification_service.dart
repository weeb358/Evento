import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_token_repository.dart';

/// Must be a top-level (or static) function, and stay outside any Riverpod
/// provider — FCM invokes this in a separate isolate when a data/notification
/// message arrives while the app is backgrounded or terminated. Kept
/// minimal: notification-message payloads already get an OS tray
/// notification for free; this only matters for data-only messages, which
/// nothing in the app sends yet.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Registers/unregisters the device's FCM token against the signed-in user
/// and wires up foreground message display. There's no reminder sender yet
/// (see docs/ROADMAP.md) — this is the receiving half only.
class NotificationService {
  NotificationService(this._repository);

  final PushTokenRepository _repository;
  final _messaging = FirebaseMessaging.instance;

  final _foregroundMessages = ValueNotifier<RemoteMessage?>(null);

  /// Listen to this to show foreground messages (e.g. a SnackBar) — see
  /// `main.dart`'s `_ForegroundNotificationBanner`.
  ValueListenable<RemoteMessage?> get foregroundMessages => _foregroundMessages;

  Future<void> requestPermissionAndRegister(String userId) async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _repository.registerToken(userId: userId, token: token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _repository.registerToken(userId: userId, token: newToken);
    });

    FirebaseMessaging.onMessage.listen((message) {
      _foregroundMessages.value = message;
    });
  }

  Future<void> unregisterCurrentDevice() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _repository.deleteToken(token);
    }
  }
}
