import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/VerifyEmail.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

void main() {
  testWidgets('submits the six-digit code and establishes the session',
      (tester) async {
    final repository = _FakeAuthRepository();
    final session = AuthSession();
    final router = _router(_service(repository, session));
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(
      find.byKey(const ValueKey('email-verification-code')),
      '123456',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('verify-email-button')),
    );
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();

    expect(repository.registrationCode, '123456');
    expect(repository.registrationChallengeId, 'initial-challenge');
    expect(session.requestHeaders, {
      'Authorization': 'Bearer registered-session',
    });
    expect(find.text('Welcome destination'), findsOneWidget);
  });

  testWidgets('resend replaces the challenge after the cooldown',
      (tester) async {
    final repository = _FakeAuthRepository();
    final router = _router(_service(repository, AuthSession()));
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Send again (60s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Send again'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resend-email-code')));
    await tester.pump();

    expect(repository.requestedEmails, ['member@example.com']);
    expect(find.text('A new verification code was sent.'), findsOneWidget);
    expect(find.text('Send again (60s)'), findsOneWidget);
  });
}

AuthService _service(AuthRepository repository, AuthSession session) =>
    AuthService(
      googleIdentityService: _UnusedGoogleIdentityService(),
      repository: repository,
      session: session,
    );

GoRouter _router(AuthService service) => GoRouter(
      initialLocation: '/verify',
      routes: [
        GoRoute(
          path: '/verify',
          builder: (_, __) => EmailVerifyScreen(
            email: 'member@example.com',
            authService: service,
            registrationDraft: const EmailRegistrationDraft(
              firstName: 'First',
              lastName: 'Last',
              username: 'member',
              email: 'member@example.com',
              password: 'Password123',
              challengeId: 'initial-challenge',
              expiresInSeconds: 600,
            ),
          ),
        ),
        GoRoute(
          path: '/session',
          builder: (_, __) => const Scaffold(body: Text('Welcome destination')),
        ),
      ],
    );

class _UnusedGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String> authenticate() => throw UnimplementedError();
}

class _FakeAuthRepository implements AuthRepository {
  final requestedEmails = <String>[];
  String? registrationChallengeId;
  String? registrationCode;

  @override
  Future<EmailCodeChallenge> requestSignUpEmailCode({
    required String email,
  }) async {
    requestedEmails.add(email);
    return const EmailCodeChallenge(
      challengeId: 'replacement-challenge',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    registrationChallengeId = challengeId;
    registrationCode = code;
    return 'registered-session';
  }

  @override
  Future<String> signInWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<String> signInWithPassword({
    required String username,
    required String password,
  }) =>
      throw UnimplementedError();
}
