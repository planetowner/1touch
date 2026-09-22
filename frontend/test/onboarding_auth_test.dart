import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/auth/auth_account_status.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'support/fake_auth_token_store.dart';

void main() {
  testWidgets('Google login disables duplicate taps and routes after success',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final googleResult = Completer<String>();
    final identityService = _FakeGoogleIdentityService(
      () => googleResult.future,
    );
    final repository = _FakeAuthRepository(
      (_) async => 'backend-access-token',
    );
    final session = AuthSession();
    final router = _router(
      AuthService(
        googleIdentityService: identityService,
        repository: repository,
        session: session,
        tokenStore: FakeAuthTokenStore(),
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.ensureVisible(
      find.byKey(const ValueKey('google-sign-in-button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('google-sign-in-button')));
    await tester.pump();

    expect(identityService.calls, 1);
    expect(repository.receivedIdTokens, isEmpty);
    expect(
        find.byKey(const ValueKey('google-sign-in-progress')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('google-sign-in-button')),
          )
          .onPressed,
      isNull,
    );

    googleResult.complete('google-id-token');
    await tester.pumpAndSettle();

    expect(repository.receivedIdTokens, ['google-id-token']);
    expect(session.isAuthenticated, isTrue);
    expect(find.text('Welcome destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google cancellation stays on onboarding without an error',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final identityService = _FakeGoogleIdentityService(
      () async => throw const GoogleIdentityException(
        GoogleIdentityFailureType.cancelled,
      ),
    );
    final router = _router(
      AuthService(
        googleIdentityService: identityService,
        repository: _FakeAuthRepository((_) async => 'unused'),
        session: AuthSession(),
        tokenStore: FakeAuthTokenStore(),
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const ValueKey('google-sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new Google account routes to profile completion',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _FakeAuthRepository(
      (_) async => 'new-social-token',
      accountStatus: const AuthAccountStatus(
        profileComplete: false,
        onboardingComplete: false,
      ),
    );
    final router = _router(
      AuthService(
        googleIdentityService:
            _FakeGoogleIdentityService(() async => 'google-id-token'),
        repository: repository,
        session: AuthSession(),
        tokenStore: FakeAuthTokenStore(),
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const ValueKey('google-sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Profile destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google authentication failure shows a recoverable error',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final router = _router(
      AuthService(
        googleIdentityService: _FakeGoogleIdentityService(
          () async => 'google-id-token',
        ),
        repository: _FakeAuthRepository(
          (_) async => throw StateError('backend unavailable'),
        ),
        session: AuthSession(),
        tokenStore: FakeAuthTokenStore(),
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const ValueKey('google-sign-in-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to sign in with Google. Please try again.'),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('google-sign-in-button')),
    );
    expect(button.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router(AuthService authService) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          authService: authService,
        ),
        routes: [
          GoRoute(
            path: 'welcome',
            builder: (context, state) => const Scaffold(
              body: Text('Welcome destination'),
            ),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const Scaffold(
              body: Text('Profile destination'),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  _FakeGoogleIdentityService(this._authenticate);

  final Future<String> Function() _authenticate;
  int calls = 0;

  @override
  Future<String> authenticate() {
    calls++;
    return _authenticate();
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(
    this._signInWithGoogle, {
    this.accountStatus = const AuthAccountStatus(
      profileComplete: true,
      onboardingComplete: false,
    ),
  });

  final Future<String> Function(String idToken) _signInWithGoogle;
  final AuthAccountStatus accountStatus;
  final List<String> receivedIdTokens = [];

  @override
  Future<String> signInWithGoogle({required String idToken}) {
    receivedIdTokens.add(idToken);
    return _signInWithGoogle(idToken);
  }

  @override
  Future<String> signInWithPassword({
    required String username,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email}) =>
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

  @override
  Future<AuthAccountStatus> loadAccountStatus(
          {required String accessToken}) async =>
      accountStatus;

  @override
  Future<AuthAccountStatus> completeSocialProfile({
    required String accessToken,
    required String username,
    required String firstName,
    required String lastName,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout({required String accessToken}) async {}
}
