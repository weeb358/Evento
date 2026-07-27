import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/email_login_screen.dart';
import '../../features/auth/presentation/screens/email_signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/public_profile_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/event_form_screen.dart';
import '../../features/events/presentation/screens/event_list_screen.dart';
import '../../features/events/presentation/screens/events_map_screen.dart';
import '../../features/events/presentation/screens/report_form_screen.dart';
import '../../features/hosting/presentation/screens/booking_request_form_screen.dart';
import '../../features/hosting/presentation/screens/host_booking_requests_screen.dart';
import '../../features/hosting/presentation/screens/host_browse_screen.dart';
import '../../features/hosting/presentation/screens/host_detail_screen.dart';
import '../../features/hosting/presentation/screens/host_profile_setup_screen.dart';
import '../../features/hosting/presentation/screens/my_bookings_screen.dart';
import '../../features/hosting/presentation/screens/my_host_listing_screen.dart';
import '../../features/premium/presentation/screens/collection_detail_screen.dart';
import '../../features/premium/presentation/screens/event_analytics_screen.dart';
import '../../features/premium/presentation/screens/event_templates_screen.dart';
import '../../features/premium/presentation/screens/paywall_screen.dart';
import '../../features/premium/presentation/screens/saved_collections_screen.dart';
import 'app_shell.dart';
import 'auth_refresh_notifier.dart';

final _authRefreshNotifierProvider = Provider<AuthRefreshNotifier>((ref) {
  final notifier = AuthRefreshNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ref.watch(_authRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/events',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isSignedIn = Supabase.instance.client.auth.currentSession != null;
      final location = state.matchedLocation;
      // These all require being signed OUT; profile setup requires being
      // signed IN (a fresh sign-in lands there when the profile is
      // incomplete — see OtpVerifyScreen/EmailSignUpScreen).
      const signInEntryRoutes = {
        '/auth/phone',
        '/auth/otp',
        '/auth/email-login',
        '/auth/email-signup',
        '/auth/forgot-password',
      };
      final isSignInEntryRoute = signInEntryRoutes.contains(location);
      final isProfileSetupRoute = location == '/auth/profile-setup';

      if (!isSignedIn && !isSignInEntryRoute) return '/auth/phone';
      if (isSignedIn && isSignInEntryRoute) return '/events';
      if (!isSignedIn && isProfileSetupRoute) return '/auth/phone';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/phone',
        name: 'authPhone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'authOtp',
        builder: (context, state) => OtpVerifyScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/auth/email-login',
        name: 'emailLogin',
        builder: (context, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: '/auth/email-signup',
        name: 'emailSignUp',
        builder: (context, state) => const EmailSignUpScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/profile-setup',
        name: 'profileSetup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/events/create',
        name: 'eventCreate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EventFormScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        name: 'eventDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            name: 'eventEdit',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => EventFormScreen(eventId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/reports/new',
        name: 'reportNew',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ReportFormScreen(
          targetType: state.uri.queryParameters['targetType']!,
          targetId: state.uri.queryParameters['targetId']!,
        ),
      ),
      GoRoute(
        path: '/premium/paywall',
        name: 'paywall',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/premium/templates',
        name: 'eventTemplates',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EventTemplatesScreen(),
      ),
      GoRoute(
        path: '/saved/:collectionId',
        name: 'savedCollectionDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CollectionDetailScreen(
          collectionId: state.pathParameters['collectionId']!,
        ),
      ),
      GoRoute(
        path: '/organizer/analytics/:eventId',
        name: 'eventAnalytics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EventAnalyticsScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/profile/:userId',
        name: 'publicProfile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PublicProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/hosting/setup',
        name: 'hostSetup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HostProfileSetupScreen(),
      ),
      GoRoute(
        path: '/hosting/my-listing',
        name: 'myHostListing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyHostListingScreen(),
      ),
      GoRoute(
        path: '/hosting/bookings',
        name: 'myBookings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/hosting/booking-requests',
        name: 'hostBookingRequests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HostBookingRequestsScreen(),
      ),
      GoRoute(
        path: '/hosting/:hostId',
        name: 'hostDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => HostDetailScreen(hostId: state.pathParameters['hostId']!),
        routes: [
          GoRoute(
            path: 'request',
            name: 'bookingRequestForm',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => BookingRequestFormScreen(
              hostId: state.pathParameters['hostId']!,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/events', name: 'events', builder: (context, state) => const EventListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', name: 'map', builder: (context, state) => const EventsMapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/saved', name: 'saved', builder: (context, state) => const SavedCollectionsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/hosting', name: 'hosting', builder: (context, state) => const HostBrowseScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', name: 'profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
