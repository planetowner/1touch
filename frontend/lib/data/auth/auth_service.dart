import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/auth_token_store.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';

// 가입·재설정은 서버와 같은 조건을 사용하고 비밀번호 원문은 바꾸지 않아요.
bool isValidNewPassword(String value) =>
    value.runes.length >= 8 &&
    value.runes.length <= 128 &&
    RegExp(r'[A-Z]').hasMatch(value) &&
    RegExp(r'[a-z]').hasMatch(value) &&
    RegExp(r'[0-9]').hasMatch(value);

class AuthService {
  const AuthService({
    required GoogleIdentityService googleIdentityService,
    required AuthRepository repository,
    required AuthSession session,
    SocialIdentityService? socialIdentityService,
    AuthTokenStore? tokenStore,
  })  : _googleIdentityService = googleIdentityService,
        _repository = repository,
        _session = session,
        _socialIdentityService = socialIdentityService,
        _tokenStore = tokenStore;

  final GoogleIdentityService _googleIdentityService;
  final AuthRepository _repository;
  final AuthSession _session;
  final SocialIdentityService? _socialIdentityService;
  final AuthTokenStore? _tokenStore;

  Future<void> signInWithProvider(LoginProvider provider) async {
    if (provider == LoginProvider.google) return signInWithGoogle();
    final identity = _socialIdentityService;
    if (identity == null) {
      throw StateError('Social identity service is missing.');
    }
    final credentials = await identity.authenticate(provider);
    final accessToken = await _repository.signInWithSocial(
      provider: provider,
      credentials: credentials,
    );
    await _establish(accessToken);
  }

  Future<void> signInWithGoogle() async {
    final idToken = await _googleIdentityService.authenticate();
    final accessToken = await _repository.signInWithGoogle(idToken: idToken);
    await _establish(accessToken);
  }

  Future<void> signInWithPassword({
    required String username,
    required String password,
  }) async {
    final accessToken = await _repository.signInWithPassword(
      username: username,
      password: password,
    );
    await _establish(accessToken);
  }

  Future<EmailCodeChallenge> requestEmailCode(
          {required String email,
          EmailCodePurpose purpose = EmailCodePurpose.signup}) =>
      _repository.requestEmailCode(email: email, purpose: purpose);

  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String password,
  }) =>
      _repository.resetPassword(
          challengeId: challengeId, code: code, password: password);

  Future<void> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    final accessToken = await _repository.registerWithEmail(
      challengeId: challengeId,
      code: code,
      password: password,
      username: username,
      firstName: firstName,
      lastName: lastName,
    );
    await _establish(accessToken);
  }

  Future<bool> restoreSession() async {
    final tokenStore = _tokenStore;
    if (tokenStore == null) return false;

    StoredAuthSession? storedSession;
    try {
      storedSession = await tokenStore.read();
    } on Object {
      // Storage availability must not prevent the app from launching.
      return false;
    }
    if (storedSession == null) return false;
    try {
      _session.establish(storedSession.accessToken);
      return true;
    } on ArgumentError {
      await tokenStore.delete();
      _session.clear();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final repository = _repository;
      if (_session.isAuthenticated && repository is LogoutAuthRepository) {
        await (repository as LogoutAuthRepository).logout();
      }
    } on Object {
      // A local logout must still work while the server is unreachable.
    } finally {
      await _tokenStore?.delete();
      _session.clear();
    }
  }

  Future<void> _establish(String accessToken) async {
    _session.establish(accessToken);
    await _tokenStore?.write(
      _session.accessToken!,
      profileComplete: false,
      onboardingComplete: false,
    );
  }
}
