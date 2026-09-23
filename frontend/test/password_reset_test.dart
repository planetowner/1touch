import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/SignComps/SignUp.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  testWidgets('signup rejects passwords that the server cannot register',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: EmailSignUpScreen()));
    final fields = find.byType(TextFormField);
    for (final (index, value) in [
      'First',
      'Last',
      'member',
      'member@example.com',
      'password123'
    ].indexed) {
      await tester.enterText(fields.at(index), value);
    }
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final submit = find.byKey(const ValueKey('email-sign-up-button'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(fields.at(4), 'Password123');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'email login trims identifier, preserves password and establishes session',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final session = AuthSession();
    final router = _router(session, (request) async {
      expect(request.url.path, '/v1/auth/login');
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"access_token":"password-session"}', 200);
    });
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('sign-in-username')), ' member@example.com ');
    await tester.enterText(
        find.byKey(const ValueKey('sign-in-password')), ' Password123 ');
    await tester
        .ensureVisible(find.byKey(const ValueKey('email-sign-in-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('email-sign-in-button')));
    await tester.pumpAndSettle();
    expect(requests, [
      {'username': 'member@example.com', 'password': ' Password123 '}
    ]);
    expect(session.isAuthenticated, isTrue);
    expect(find.text('Session destination'), findsOneWidget);
  });

  testWidgets(
      'small screen keeps password and submit reachable above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final session = AuthSession();
    final router = _router(session,
        (_) async => http.Response('{"access_token":"keyboard-session"}', 200));
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('sign-in-username')), 'member');
    await tester.ensureVisible(find.byKey(const ValueKey('sign-in-password')));
    await tester.enterText(
        find.byKey(const ValueKey('sign-in-password')), 'Password123');
    await tester
        .ensureVisible(find.byKey(const ValueKey('email-sign-in-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('email-sign-in-button')));
    await tester.pumpAndSettle();
    expect(session.isAuthenticated, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reset requests a dedicated code, retries invalid code, then returns without signing in',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = AuthSession();
    final requests = <(String, Map<String, dynamic>)>[];
    var codeCount = 0;
    final router = _router(session, (request) async {
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add((request.url.path, data));
      if (request.url.path == '/v1/auth/email/code') {
        codeCount++;
        expect(
            data, {'email': 'member@example.com', 'purpose': 'password_reset'});
        return http.Response(
            jsonEncode(
                {'challenge_id': 'challenge-$codeCount', 'expires_in': 600}),
            200);
      }
      expect(request.url.path, '/v1/auth/email/reset-password');
      expect(data['challenge_id'], 'challenge-2');
      expect(data['password'], 'NewPassword123');
      return data['code'] == '123456'
          ? http.Response('{"ok":true}', 200)
          : http.Response(
              '{"detail":"Invalid, expired, or exhausted verification code"}',
              400);
    });
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forgot-password-link')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reset-email')), ' member@example.com ');
    await tester.tap(find.byKey(const ValueKey('request-reset-code')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-new-password')), findsOneWidget);
    expect(session.isAuthenticated, isFalse);
    await tester.tap(find.byKey(const ValueKey('resend-email-code')));
    expect(codeCount, 1);
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.byKey(const ValueKey('resend-email-code')));
    await tester.pumpAndSettle();
    expect(codeCount, 2);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('email-verification-code')), '000000');
    await tester.enterText(
        find.byKey(const ValueKey('reset-new-password')), 'weak');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('verify-email-button')))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byKey(const ValueKey('reset-new-password')), 'NewPassword123');
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('verify-email-button')));
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid, expired, or exhausted verification code (400)'),
        findsOneWidget);
    expect(session.isAuthenticated, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('email-verification-code')), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sign-in-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-new-password')), findsNothing);
    expect(find.text('Password reset. Sign in with your new password.'),
        findsOneWidget);
    expect(session.isAuthenticated, isFalse);
    expect(requests.length, 4);
    expect(tester.takeException(), isNull);
  });
}

MaterialApp _app(GoRouter router) => MaterialApp.router(
    routerConfig: router,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates);

GoRouter _router(
    AuthSession session, Future<http.Response> Function(http.Request) handler) {
  final service = AuthService(
      googleIdentityService: _UnusedGoogle(),
      session: session,
      repository: ApiGoogleAuthRepository(
          api: ApiClient(
              baseUri: Uri.parse('https://api.example.test/v1/'),
              requestHeaders: () => {},
              client: MockClient(handler))));
  return GoRouter(initialLocation: '/onboarding', routes: [
    GoRoute(
        path: '/onboarding',
        builder: (_, __) => OnboardingScreen(
            authService: service,
            loadOptions: () async => const LoginOptions(
                recommended: [LoginProvider.google, LoginProvider.email]))),
    GoRoute(
        path: '/session',
        builder: (_, __) => const Scaffold(body: Text('Session destination'))),
  ]);
}

class _UnusedGoogle implements GoogleIdentityService {
  @override
  Future<String> authenticate() => throw UnimplementedError();
}
