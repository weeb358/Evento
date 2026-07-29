import 'package:events_app/core/theme/app_theme.dart';
import 'package:events_app/features/auth/presentation/screens/email_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Full-app smoke testing needs a live (or mocked) Supabase client — the
/// real router's redirect logic reads `Supabase.instance.client.auth`. This
/// test instead renders the email login screen in isolation, which is a
/// meaningful check (theme applies, the screen builds, its content is
/// visible) without requiring Supabase test doubles. Doesn't trigger any
/// sign-in action, so it never touches `authRepositoryProvider` (which
/// reads `dotenv.env`, not loaded in this test).
void main() {
  testWidgets('email login screen renders with the app theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const EmailLoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  test('AppTheme builds light and dark ThemeData without throwing', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });
}
