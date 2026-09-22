import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/auth/auth_account_status.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
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
      tokenStore: FakeAuthTokenStore(),
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
      tokenStore: FakeAuthTokenStore(),
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
      tokenStore: FakeAuthTokenStore(),
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
      tokenStore: FakeAuthTokenStore(),
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

  test('restores a valid saved session and its onboarding state', () async {
    final store = FakeAuthTokenStore()
      ..value = const StoredAuthSession(
        accessToken: 'stored-token',
        profileComplete: true,
        onboardingComplete: false,
      );
    final repository = _FakeAuthRepository(
      (_) async => throw UnimplementedError(),
      loadAccountStatus: (_) async => const AuthAccountStatus(
        profileComplete: true,
        onboardingComplete: true,
      ),
    );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => throw UnimplementedError(),
      ),
      repository: repository,
      session: session,
      tokenStore: store,
    );

    expect(await service.restoreSession(), isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.onboardingComplete, isTrue);
    expect(store.value?.onboardingComplete, isTrue);
  });

  test('removes an expired saved session after a 401 response', () async {
    final store = FakeAuthTokenStore()
      ..value = const StoredAuthSession(
        accessToken: 'expired-token',
        profileComplete: true,
        onboardingComplete: true,
      );
    final repository = _FakeAuthRepository(
      (_) async => throw UnimplementedError(),
      loadAccountStatus: (_) async => throw const AuthRequestException(
        statusCode: 401,
        message: 'Invalid or expired session',
      ),
    );
    final session = AuthSession();
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => throw UnimplementedError(),
      ),
      repository: repository,
      session: session,
      tokenStore: store,
    );

    expect(await service.restoreSession(), isFalse);
    expect(session.isAuthenticated, isFalse);
    expect(store.value, isNull);
  });

  test('logout clears both the backend and local sessions', () async {
    final store = FakeAuthTokenStore()
      ..value = const StoredAuthSession(
        accessToken: 'active-token',
        profileComplete: true,
        onboardingComplete: true,
      );
    final repository = _FakeAuthRepository(
      (_) async => throw UnimplementedError(),
    );
    final session = AuthSession()
      ..establish(
        'active-token',
        onboardingComplete: true,
        persistent: true,
      );
    final service = AuthService(
      googleIdentityService: _FakeGoogleIdentityService(
        () async => throw UnimplementedError(),
      ),
      repository: repository,
      session: session,
      tokenStore: store,
    );

    await service.logout();

    expect(repository.loggedOutTokens, ['active-token']);
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

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(
    this._signInWithGoogle, {
    Future<String> Function()? registerWithEmail,
    Future<AuthAccountStatus> Function(String accessToken)? loadAccountStatus,
  })  : _registerWithEmail = registerWithEmail,
        _loadAccountStatus = loadAccountStatus;

  final Future<String> Function(String idToken) _signInWithGoogle;
  final Future<String> Function()? _registerWithEmail;
  final Future<AuthAccountStatus> Function(String accessToken)?
      _loadAccountStatus;
  final List<String> receivedIdTokens = [];
  final List<String> loggedOutTokens = [];

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
      _registerWithEmail?.call() ?? Future.error(UnimplementedError());

  @override
  Future<AuthAccountStatus> loadAccountStatus({required String accessToken}) =>
      _loadAccountStatus?.call(accessToken) ??
      Future.value(
        const AuthAccountStatus(
          profileComplete: true,
          onboardingComplete: true,
        ),
      );

  @override
  Future<AuthAccountStatus> completeSocialProfile({
    required String accessToken,
    required String username,
    required String firstName,
    required String lastName,
  }) async =>
      const AuthAccountStatus(
        profileComplete: true,
        onboardingComplete: false,
      );

  @override
  Future<void> logout({required String accessToken}) async {
    loggedOutTokens.add(accessToken);
  }
}
