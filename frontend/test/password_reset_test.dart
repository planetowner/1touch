import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/SignComps/sign_up.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/messages.dart';

void main() {
  testWidgets('reset code request shows a localized failure and can be retried',
      (tester) async {
    var failRequest = true;
    final router = _router(
        AuthSession(),
        (_) async => failRequest
            ? http.Response(
                '{"detail":"Service configuration missing: INTERNAL_SECRET"}',
                503)
            : http.Response(
                '{"challenge_id":"challenge","expires_in":600}', 200));
    addTearDown(router.dispose);
    await _openResetCodeRequest(tester, router, locale: const Locale('ko'));
    await tester.tap(find.byKey(const ValueKey('request-reset-code')));
    await tester.pumpAndSettle();
    expect(find.text('일시적인 문제가 생겼어요. 잠시 후 다시 시도해 주세요.').hitTestable(),
        findsOneWidget);
    expect(find.textContaining('INTERNAL_SECRET'), findsNothing);
    expect(find.byKey(const ValueKey('reset-email')), findsOneWidget);
    failRequest = false;
    await tester.tap(find.byKey(const ValueKey('request-reset-code')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('email-verification-code')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final locale in appSupportedLocales) {
    for (final entry in verificationCodeErrorMessages.entries) {
      testWidgets(
          '${entry.key} returns to code entry in ${locale.languageCode}',
          (tester) async {
        final session = AuthSession();
        final router = _router(session, (request) async {
          if (request.url.path == '/v1/auth/email/code') {
            return http.Response(
                '{"challenge_id":"challenge","expires_in":600}', 200);
          }
          expect(request.url.path, '/v1/auth/email/reset-password');
          return http.Response(
              jsonEncode({
                'detail': {
                  'code': entry.key,
                  'message': 'Server wording can change',
                }
              }),
              400);
        });
        addTearDown(router.dispose);
        await _openResetPasswordStep(tester, router, locale: locale);
        await tester.tap(find.byKey(const ValueKey('verify-email-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('email-verification-code')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('reset-new-password')), findsNothing);
        final translated = translateMessage(locale, entry.value);
        expect(find.text(translated).hitTestable(), findsOneWidget);
        expect(find.textContaining('Server wording'), findsNothing);
        expect(session.isAuthenticated, isFalse);
        await tester.pump(const Duration(seconds: 61));
        await tester.tap(find.byKey(const ValueKey('resend-email-code')));
        await tester.pumpAndSettle();
        expect(find.text(translated), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final (status, code, message) in [
    (400, 'unknown_error', 'Unable to reset your password. Please try again.'),
    (422, null, 'Unable to reset your password. Please try again.'),
    (429, 'auth_rate_limited', 'Too many requests. Please try again later.'),
    (
      503,
      null,
      'The service is temporarily unavailable. Please try again later.'
    ),
  ]) {
    testWidgets(
        'reset failure $status keeps password entry and uses local copy',
        (tester) async {
      final router = _router(
          AuthSession(),
          (request) async => request.url.path == '/v1/auth/email/code'
              ? http.Response(
                  '{"challenge_id":"challenge","expires_in":600}', 200)
              : http.Response(
                  jsonEncode({
                    'detail': {
                      'code': code,
                      'message': 'Internal server details',
                    }
                  }),
                  status));
      addTearDown(router.dispose);
      await _openResetPasswordStep(tester, router, locale: const Locale('ko'));
      await tester.tap(find.byKey(const ValueKey('verify-email-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reset-new-password')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('email-verification-code')), findsNothing);
      expect(find.text(translateMessage(const Locale('ko'), message)),
          findsOneWidget);
      expect(find.textContaining('Internal server'), findsNothing);
    });
  }

  testWidgets('signup rejects passwords that the server cannot register',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSignup(tester);
    expect(
        find.text(
            'Use 8–128 characters with at least one uppercase letter, one lowercase letter, and one number.'),
        findsOneWidget);
    await _fillSignup(tester, password: 'password123');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final submit = find.byKey(const ValueKey('email-sign-up-button'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(
        find.text(
            'Include at least one uppercase letter, one lowercase letter, and one number.'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('signup-password-field')), 'Password123');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.enterText(
        find.byKey(const ValueKey('signup-confirm-password-field')),
        'Different123');
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text("The passwords don't match. Please check again."),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('signup-confirm-password-field')),
        'Password123');
    await tester.pump();
    // 중복 확인이 끝난 뒤 비밀번호 검증을 통과하면 제출할 수 있어요.
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup button explains missing terms consent', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSignup(tester);
    await _fillSignup(tester, password: 'Password123', confirm: 'Password123');
    await tester.tap(find.byKey(const ValueKey('email-sign-up-button')));
    await tester.pump();
    expect(find.text('Please agree to the Terms and Privacy Policy.'),
        findsOneWidget);
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
        expect(data, {
          'email': 'member@example.com',
          'purpose': 'password_reset',
          'language': 'en',
        });
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
              '{"detail":{"code":"verification_code_invalid"}}', 400);
    });
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forgot-password-link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sign-in-username')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('reset-email')), ' member@example.com ');
    await tester.tap(find.byKey(const ValueKey('request-reset-code')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('email-verification-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-new-password')), findsNothing);
    expect(session.isAuthenticated, isFalse);
    await tester.tap(find.byKey(const ValueKey('resend-email-code')));
    expect(codeCount, 1);
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.byKey(const ValueKey('resend-email-code')));
    await tester.pumpAndSettle();
    expect(codeCount, 2);
    await tester.enterText(
        find.byKey(const ValueKey('email-verification-code')), '000000');
    await tester.tap(find.byKey(const ValueKey('continue-reset-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-new-password')), findsOneWidget);
    expect(find.text(passwordGuideMessage), findsOneWidget);
    // 기본 배너는 직접 닫아야 하므로 재전송 안내부터 닫고 입력을 검증해요.
    await tester.tap(find.byKey(const ValueKey('app-rule-notice-close')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reset-new-password')), 'weak');
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(find.text('Use 8–128 characters.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-rule-notice-close')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reset-new-password')), 'NewPassword123');
    await tester.enterText(find.byKey(const ValueKey('reset-confirm-password')),
        'OtherPassword123');
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(find.text("The passwords don't match. Please check again."),
        findsOneWidget);
    // 하단 버튼을 덮는 오류 안내가 닫힌 뒤 다시 제출해요.
    await tester.tap(find.byKey(const ValueKey('app-rule-notice-close')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password')), 'NewPassword123');
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('verify-email-button')));
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid verification code. Try again.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('email-verification-code')), findsOneWidget);
    expect(session.isAuthenticated, isFalse);
    await tester.enterText(
        find.byKey(const ValueKey('email-verification-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('continue-reset-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reset-new-password')), 'NewPassword123');
    await tester.enterText(
        find.byKey(const ValueKey('reset-confirm-password')), 'NewPassword123');
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

Future<void> _pumpSignup(WidgetTester tester) async {
  final service = _service(AuthSession(), (request) async {
    expect(request.url.path, '/v1/auth/registration/availability');
    return http.Response('{"available":true}', 200);
  });
  await tester
      .pumpWidget(MaterialApp(home: EmailSignUpScreen(authService: service)));
}

Future<void> _fillSignup(WidgetTester tester,
    {required String password, String? confirm}) async {
  for (final (key, value) in [
    ('signup-username-field', 'member'),
    ('signup-display-name-field', 'Member'),
    ('signup-email-field', 'member@example.com'),
    ('signup-password-field', password),
    if (confirm != null) ('signup-confirm-password-field', confirm),
  ]) {
    await tester.enterText(find.byKey(ValueKey(key)), value);
  }
  // 비밀번호 검증은 외부 요청 없이 중복 확인이 완료된 상태에서 확인해요.
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

Future<void> _openResetCodeRequest(WidgetTester tester, GoRouter router,
    {required Locale locale}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(router, locale: locale));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('forgot-password-link')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('reset-email')), 'member@example.com');
}

Future<void> _openResetPasswordStep(WidgetTester tester, GoRouter router,
    {required Locale locale}) async {
  await _openResetCodeRequest(tester, router, locale: locale);
  await tester.tap(find.byKey(const ValueKey('request-reset-code')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('email-verification-code')), '000000');
  await tester.tap(find.byKey(const ValueKey('continue-reset-password')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('reset-new-password')), 'NewPassword123');
  await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-password')), 'NewPassword123');
}

MaterialApp _app(GoRouter router, {Locale? locale}) => MaterialApp.router(
    routerConfig: router,
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates);

AuthService _service(AuthSession session,
        Future<http.Response> Function(http.Request) handler) =>
    AuthService(
        googleIdentityService: _UnusedGoogle(),
        session: session,
        repository: ApiGoogleAuthRepository(
            api: ApiClient(
                baseUri: Uri.parse('https://api.example.test/v1/'),
                requestHeaders: () => {},
                client: MockClient(handler))));

GoRouter _router(
    AuthSession session, Future<http.Response> Function(http.Request) handler) {
  final service = _service(session, handler);
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
