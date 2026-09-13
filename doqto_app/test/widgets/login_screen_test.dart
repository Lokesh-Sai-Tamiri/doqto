import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/ui/screens/auth/login_screen.dart';
import 'package:doqto_app/ui/widgets/phone_field.dart';
import 'package:doqto_app/ui/widgets/social_button.dart';

// The login screen offers four ways in. Phone OTP is the only one wired to the
// backend; the rest must still be visible and must say so when tapped.
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

  // The screen scrolls; error text can push a button below the test viewport.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('all four sign-in methods are on screen', (tester) async {
    await pump(tester);

    // Phone is the default tab.
    expect(find.byType(PhoneField), findsOneWidget);

    // No separate sign-up: the number decides — known means sign in, new
    // means sign up.
    expect(find.text('Create an account'), findsNothing);
    expect(find.text('New to Doqto?'), findsNothing);
    expect(find.text(Strings.authSendOtp), findsWidgets);

    // Both providers are offered regardless of the selected tab.
    expect(find.byType(SocialButton), findsNWidgets(2));
    expect(find.text(Strings.loginGoogle), findsOneWidget);
    expect(find.text(Strings.loginFacebook), findsOneWidget);

    // Switching to Email swaps the form, not the rest of the screen.
    await tap(tester, find.text(Strings.loginTabEmail));

    expect(find.byType(PhoneField), findsNothing);
    // The tab and the field share a label, so match the field by its hint.
    expect(find.text(Strings.loginIdentifierHint), findsOneWidget);
    expect(find.text(Strings.loginPassword), findsOneWidget);
    expect(find.text(Strings.loginForgotPassword), findsOneWidget);
    expect(find.text(Strings.loginSignIn), findsWidgets);
    expect(find.byType(SocialButton), findsNWidgets(2));
  });

  testWidgets('password sign-in takes a username or an email', (tester) async {
    await pump(tester);
    await tap(tester, find.text(Strings.loginTabEmail));

    final fields = find.byType(TextField);

    // An @ means they meant an email, so they get the email error.
    await tester.enterText(fields.at(0), 'not-an-email@');
    await tester.enterText(fields.at(1), 'hunter2hunter2');
    await tap(tester, find.text(Strings.loginSignIn).first);

    expect(find.text('That doesn\'t look like an email address.'), findsOneWidget);
    expect(find.text(Strings.loginComingSoon), findsNothing);

    // No @ means a username, judged by username rules.
    await tester.enterText(fields.at(0), 'dr alex');
    await tap(tester, find.text(Strings.loginSignIn).first);

    expect(find.text('Usernames use letters, digits, dot, dash or underscore.'),
        findsOneWidget);
    expect(find.text(Strings.loginComingSoon), findsNothing);

    // Short password — same deal.
    await tester.enterText(fields.at(0), 'dr.alex');
    await tester.enterText(fields.at(1), 'short');
    await tap(tester, find.text(Strings.loginSignIn).first);

    expect(find.text('Passwords are at least 8 characters.'), findsOneWidget);
    expect(find.text(Strings.loginComingSoon), findsNothing);

    // A plain username with a long enough password gets through validation;
    // the screen then admits the endpoint isn't live yet.
    await tester.enterText(fields.at(1), 'hunter2hunter2');
    await tap(tester, find.text(Strings.loginSignIn).first);

    expect(find.text(Strings.loginComingSoon), findsOneWidget);

    // So does an email address in the same field.
    await tester.enterText(fields.at(0), 'doc@hospital.org');
    await tap(tester, find.text(Strings.loginSignIn).first);

    expect(find.text(Strings.loginComingSoon), findsOneWidget);
  });

  testWidgets('a provider button reports being unavailable', (tester) async {
    await pump(tester);

    await tap(tester, find.text(Strings.loginGoogle));

    expect(find.text(Strings.loginComingSoon), findsOneWidget);
  });
}
