import 'package:onetouch/data/auth/login_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/SignComps/sign_in.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/registration_field.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  for (final entry in {
    'en': [
      'Your email, username, or password is incorrect.',
      'Please check your connection and try again.',
      'The service is temporarily unavailable. Please try again later.',
    ],
    'ko': [
      '이메일·아이디 또는 비밀번호가 올바르지 않아요.',
      '연결 상태를 확인하고 다시 시도해 주세요.',
      '일시적인 문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
    ],
    'ja': [
      'メールアドレス、ユーザー名、またはパスワードが正しくありません。',
      '接続を確認して再度お試しください。',
      '一時的な問題が発生しました。しばらくしてからもう一度お試しください。',
    ],
    'zh': [
      '邮箱、用户名或密码不正确。',
      '请检查网络连接后重试。',
      '出现了临时问题，请稍后重试。',
    ],
  }.entries) {
    for (var failure = 0; failure < entry.value.length; failure++) {
      testWidgets(
          'password login distinguishes failure $failure in ${entry.key}',
          (tester) async {
        await _setScreenSize(tester, const Size(393, 852));
        var requests = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            requests++;
            expect(request.url.path, '/v1/auth/login');
            if (failure == 1) throw http.ClientException('Connection refused');
            // 서버가 HTML 오류 페이지를 보내도 연결 오류로 분류하지 않아요.
            return failure == 0
                ? http.Response(
                    '{"detail":"Invalid email, username, or password"}', 401)
                : http.Response('<html>Service unavailable</html>', 503);
          }),
          baseUri: Uri.parse('https://example.test/v1/'),
          requestHeaders: () => {},
        );
        addTearDown(api.close);
        final session = AuthSession();
        final router = _router(
          _service(session, ApiGoogleAuthRepository(api: api)),
          initialLocation: '/onboarding',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(
          routerConfig: router,
          locale: Locale(entry.key),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
        ));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const ValueKey('sign-in-username')), 'member');
        await tester.enterText(
            find.byKey(const ValueKey('sign-in-password')), 'Password123');
        final button = find.byKey(const ValueKey('email-sign-in-button'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(requests, 1);
        expect(find.text(entry.value[failure]), findsOneWidget);
        for (var other = 0; other < entry.value.length; other++) {
          if (other != failure) {
            expect(find.text(entry.value[other]), findsNothing);
          }
        }
        expect(session.isAuthenticated, isFalse);
        expect(find.text('Home destination'), findsNothing);
        expect(tester.widget<AuthPrimaryButton>(button).onPressed, isNotNull);
        expect(
            find.byKey(const ValueKey('email-sign-in-progress')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('onboarding includes password fields and opens signup',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final service = _service(AuthSession(), _FakeAuthRepository());
    final router = _router(service, initialLocation: '/onboarding');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Continue with email'), findsNothing);
    expect(find.byKey(const ValueKey('sign-in-username')), findsOneWidget);
    final passwordField = find.ancestor(
      of: find.byKey(const ValueKey('sign-in-password')),
      matching: find.byType(AuthInput),
    );
    expect(
      tester.getTopLeft(passwordField).dy -
          tester
              .getBottomLeft(find.byKey(const ValueKey('sign-in-username')))
              .dy,
      16,
    );
    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('sign-in-sign-up-link')));
    await tester.tap(find.byKey(const ValueKey('sign-in-sign-up-link')));
    await tester.pumpAndSettle();
    expect(find.text('Signup destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password sign in establishes the in-memory session',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final session = AuthSession();
    final repository = _FakeAuthRepository();
    final router = _router(
      _service(session, repository),
      initialLocation: '/auth/signin',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(
      find.byKey(const ValueKey('sign-in-username')),
      ' member ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('sign-in-password')),
      'Password123',
    );
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('email-sign-in-button')));
    await tester.tap(find.byKey(const ValueKey('email-sign-in-button')));
    await tester.pumpAndSettle();

    expect(repository.passwordCredentials, [('member', 'Password123')]);
    expect(session.requestHeaders, {
      'Authorization': 'Bearer password-access-token',
    });
    expect(find.text('Home destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final route in ['/onboarding', '/auth/signin']) {
    testWidgets('keyboard advances to password and submits login at $route',
        (tester) async {
      await _setScreenSize(tester, const Size(393, 852));
      final repository = _FakeAuthRepository();
      final router =
          _router(_service(AuthSession(), repository), initialLocation: route);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign-in-username')));
      tester.testTextInput.enterText('member');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      final password = find.descendant(
          of: find.byKey(const ValueKey('sign-in-password')),
          matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(password).focusNode.hasFocus, isTrue);
      tester.testTextInput.enterText('Password123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repository.passwordCredentials, [('member', 'Password123')]);
      expect(find.text('Home destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

AuthService _service(AuthSession session, AuthRepository repository) =>
    AuthService(
      googleIdentityService: _FakeGoogleIdentityService(),
      repository: repository,
      session: session,
    );

GoRouter _router(AuthService service, {required String initialLocation}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => OnboardingScreen(
              authService: service,
              loadOptions: () async => const LoginOptions(recommended: [
                    LoginProvider.google,
                    LoginProvider.apple,
                    LoginProvider.email
                  ])),
        ),
        GoRoute(
          path: '/auth/signin',
          builder: (_, __) => EmailSignInScreen(authService: service),
        ),
        GoRoute(
          path: '/auth/signup',
          builder: (_, __) => const Scaffold(
            body: Text('Signup destination'),
          ),
        ),
        GoRoute(
          path: '/session',
          builder: (_, __) => const Scaffold(body: Text('Home destination')),
        ),
      ],
    );

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String> authenticate() => throw UnimplementedError();
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<bool> isRegistrationValueAvailable({
    required RegistrationField field,
    required String value,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword(
          {required String challengeId,
          required String code,
          required String password}) =>
      throw UnimplementedError();

  @override
  Future<String> signInWithSocial(
          {required LoginProvider provider,
          required Map<String, String> credentials}) =>
      throw UnimplementedError();

  final passwordCredentials = <(String, String)>[];

  @override
  Future<String> signInWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<String> signInWithPassword({
    required String username,
    required String password,
  }) async {
    passwordCredentials.add((username, password));
    return 'password-access-token';
  }

  @override
  Future<EmailCodeChallenge> requestEmailCode(
          {required String email,
          EmailCodePurpose purpose = EmailCodePurpose.signup}) =>
      throw UnimplementedError();

  @override
  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String displayName,
  }) =>
      throw UnimplementedError();
}
