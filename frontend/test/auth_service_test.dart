import 'package:onetouch/data/auth/login_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/auth_token_store.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'support/fake_auth_token_store.dart';

void main() {
  test('exchanges a Google ID token and stores only the backend token',
      () async {
    final identityService = _FakeGoogleIdentityService(
      () async => 'google-id-token',
    );
    final repository = _FakeAuthRepository(
      (idToken) async => ' backend-access-token ',
    );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: identityService,
      repository: repository,
      session: session,
    );

    await service.signInWithGoogle();

    expect(repository.receivedIdTokens, ['google-id-token']);
    expect(session.isAuthenticated, isTrue);
    expect(session.requestHeaders, {
      'Authorization': 'Bearer backend-access-token',
    });
    expect(session.requestHeaders.values, isNot(contains('google-id-token')));
    expect(
      () => session.requestHeaders['Authorization'] = 'changed',
      throwsUnsupportedError,
    );
  });

  test('does not call the backend or establish a session when Google fails',
      () async {
    const failure = GoogleIdentityException(
      GoogleIdentityFailureType.cancelled,
    );
    final identityService = _FakeGoogleIdentityService(
      () async => throw failure,
    );
    final repository = _FakeAuthRepository(
      (_) async => 'unused-access-token',
    );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: identityService,
      repository: repository,
      session: session,
    );

    await expectLater(service.signInWithGoogle(), throwsA(same(failure)));

    expect(repository.receivedIdTokens, isEmpty);
    expect(session.isAuthenticated, isFalse);
    expect(session.requestHeaders, isEmpty);
  });

  test('does not establish a session when the backend exchange fails',
      () async {
    final failure = StateError('backend unavailable');
    final identityService = _FakeGoogleIdentityService(
      () async => 'google-id-token',
    );
    final repository = _FakeAuthRepository(
      (_) async => throw failure,
    );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: identityService,
      repository: repository,
      session: session,
    );

    await expectLater(service.signInWithGoogle(), throwsA(same(failure)));

    expect(session.isAuthenticated, isFalse);
    expect(session.requestHeaders, isEmpty);
  });

  test('rejects an empty backend token', () {
    final session = AuthSession();

    expect(() => session.establish('  '), throwsArgumentError);
    expect(session.isAuthenticated, isFalse);
  });

  test('email registration establishes the backend session', () async {
    final repository = _FakeAuthRepository(
      (_) async => throw UnimplementedError(),
      registerWithEmail: () async => ' email-access-token ',
    );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => throw UnimplementedError(),
      ),
      repository: repository,
      session: session,
    );

    await service.registerWithEmail(
      challengeId: 'challenge',
      code: '123456',
      password: 'Password123',
      username: 'member',
      firstName: 'First',
      lastName: 'Last',
    );

    expect(session.requestHeaders, {
      'Authorization': 'Bearer email-access-token',
    });
  });

  test('persists a successful backend session', () async {
    final store = FakeAuthTokenStore();
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => 'google-id-token',
      ),
      repository: _FakeAuthRepository((_) async => 'backend-access-token'),
      session: AuthSession(),
      tokenStore: store,
    );

    await service.signInWithGoogle();

    expect(store.value?.accessToken, 'backend-access-token');
  });

  test('restores a saved session', () async {
    final store = FakeAuthTokenStore()
      ..value = const StoredAuthSession(
        accessToken: 'stored-token',
        profileComplete: false,
        onboardingComplete: false,
      );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => throw UnimplementedError(),
      ),
      repository: _FakeAuthRepository((_) async => throw UnimplementedError()),
      session: session,
      tokenStore: store,
    );

    expect(await service.restoreSession(), isTrue);
    expect(session.accessToken, 'stored-token');
  });

  test('logout revokes and clears the saved session', () async {
    final store = FakeAuthTokenStore()
      ..value = const StoredAuthSession(
        accessToken: 'active-token',
        profileComplete: false,
        onboardingComplete: false,
      );
    final repository =
        _FakeAuthRepository((_) async => throw UnimplementedError());
    final session = AuthSession()..establish('active-token');
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => throw UnimplementedError(),
      ),
      repository: repository,
      session: session,
      tokenStore: store,
    );

    await service.logout();

    expect(repository.logoutCalls, 1);
    expect(session.isAuthenticated, isFalse);
    expect(store.value, isNull);
  });
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  _FakeGoogleIdentityService(this._authenticate);

  final Future<String> Function() _authenticate;

  @override
  Future<String> authenticate() => _authenticate();
}

class _FakeAuthRepository implements AuthRepository, LogoutAuthRepository {
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

  _FakeAuthRepository(
    this._signInWithGoogle, {
    Future<String> Function()? registerWithEmail,
  }) : _registerWithEmail = registerWithEmail;

  final Future<String> Function(String idToken) _signInWithGoogle;
  final Future<String> Function()? _registerWithEmail;
  final List<String> receivedIdTokens = [];
  int logoutCalls = 0;

  @override
  Future<void> logout() async => logoutCalls++;

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
      _registerWithEmail?.call() ?? Future.error(UnimplementedError());
}
