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
  testWidgets('Continue with email opens sign in and signup link is aligned',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final service = _service(AuthSession(), _FakeAuthRepository());
    final router = _router(service, initialLocation: '/onboarding');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.ensureVisible(find.text('Continue with email'));
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Need sign up?'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Remember me')).dy,
      closeTo(tester.getCenter(find.text('Need sign up?')).dy, 1),
    );

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
          builder: (_, __) => OnboardingScreen(authService: service),
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
          path: '/home',
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
  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email}) =>
      throw UnimplementedError();
}
