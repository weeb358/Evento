import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_providers.dart';
import 'core/theme/app_theme.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: EventsApp()));
}

class EventsApp extends ConsumerWidget {
  const EventsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    ref.listen(currentUserIdProvider, (previous, next) {
      final notificationService = ref.read(notificationServiceProvider);
      if (next != null) {
        notificationService.requestPermissionAndRegister(next);
      } else if (previous != null) {
        notificationService.unregisterCurrentDevice();
      }
    });

    return _ForegroundNotificationBanner(
      child: MaterialApp.router(
        title: 'Events Platform',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        routerConfig: router,
      ),
    );
  }
}

/// Shows a SnackBar for messages that arrive while the app is open — FCM
/// only puts a system tray notification up automatically when the app is
/// backgrounded or terminated.
class _ForegroundNotificationBanner extends ConsumerStatefulWidget {
  const _ForegroundNotificationBanner({required this.child});

  final Widget child;

  @override
  ConsumerState<_ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState extends ConsumerState<_ForegroundNotificationBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).foregroundMessages.addListener(_onMessage);
    });
  }

  void _onMessage() {
    final message = ref.read(notificationServiceProvider).foregroundMessages.value;
    final notification = message?.notification;
    if (notification == null) return;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text([notification.title, notification.body].where((s) => s != null).join(' — ')),
      ),
    );
  }

  @override
  void dispose() {
    ref.read(notificationServiceProvider).foregroundMessages.removeListener(_onMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
