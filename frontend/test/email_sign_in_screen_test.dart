import 'package:onetouch/data/auth/login_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/SignComps/SignIn.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

void main() {
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
    required String firstName,
    required String lastName,
  }) =>
      throw UnimplementedError();
}
