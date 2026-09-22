import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/CompleteSocialProfile.dart';
import 'package:onetouch/data/auth/auth_account_status.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'support/fake_auth_token_store.dart';

void main() {
  testWidgets('social profile is saved before team onboarding', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeAuthRepository();
    final session = AuthSession()
      ..establish(
        'social-token',
        profileComplete: false,
        onboardingComplete: false,
        persistent: true,
      );
    final service = AuthService(
      googleIdentityService: _UnusedGoogleIdentityService(),
      repository: repository,
      session: session,
      tokenStore: FakeAuthTokenStore(),
    );
    final router = GoRouter(
      initialLocation: '/onboarding/profile',
      routes: [
        GoRoute(
          path: '/onboarding/profile',
          builder: (_, __) => CompleteSocialProfileScreen(
            authService: service,
          ),
        ),
        GoRoute(
          path: '/onboarding/welcome',
          builder: (_, __) => const Scaffold(body: Text('Welcome destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(
      find.byKey(const ValueKey('social-profile-first-name')),
      ' First ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('social-profile-last-name')),
      ' Last ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('social-profile-username')),
      ' member ',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('social-profile-continue')),
    );
    await tester.tap(find.byKey(const ValueKey('social-profile-continue')));
    await tester.pumpAndSettle();

    expect(repository.completedProfiles, [
      ('social-token', 'member', 'First', 'Last'),
    ]);
    expect(session.profileComplete, isTrue);
    expect(session.onboardingComplete, isFalse);
    expect(find.text('Welcome destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnusedGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String> authenticate() => throw UnimplementedError();
}

class _FakeAuthRepository implements AuthRepository {
  final completedProfiles = <(String, String, String, String)>[];

  @override
  Future<AuthAccountStatus> completeSocialProfile({
    required String accessToken,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    completedProfiles.add((accessToken, username, firstName, lastName));
    return const AuthAccountStatus(
      profileComplete: true,
      onboardingComplete: false,
    );
  }

  @override
  Future<AuthAccountStatus> loadAccountStatus({required String accessToken}) =>
      throw UnimplementedError();

  @override
  Future<void> logout({required String accessToken}) =>
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
  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email}) =>
      throw UnimplementedError();

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
