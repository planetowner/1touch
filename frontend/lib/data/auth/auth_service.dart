import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_account_status.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/auth_token_store.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

class AuthService {
  static const _sessionValidationTimeout = Duration(seconds: 10);

  const AuthService({
    required GoogleIdentityService googleIdentityService,
    required AuthRepository repository,
    required AuthSession session,
    required AuthTokenStore tokenStore,
  })  : _googleIdentityService = googleIdentityService,
        _repository = repository,
        _session = session,
        _tokenStore = tokenStore;

  final GoogleIdentityService _googleIdentityService;
  final AuthRepository _repository;
  final AuthSession _session;
  final AuthTokenStore _tokenStore;

  Future<AuthAccountStatus> signInWithGoogle() async {
    final idToken = await _googleIdentityService.authenticate();
    final accessToken = await _repository.signInWithGoogle(idToken: idToken);
    return _establishValidated(accessToken, persist: true);
  }

  Future<AuthAccountStatus> signInWithPassword({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final accessToken = await _repository.signInWithPassword(
      username: username,
      password: password,
    );
    return _establishValidated(accessToken, persist: rememberMe);
  }

  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email}) =>
      _repository.requestSignUpEmailCode(email: email);

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
    await _tokenStore.write(
      accessToken,
      profileComplete: true,
      onboardingComplete: false,
    );
    _session.establish(
      accessToken,
      profileComplete: true,
      onboardingComplete: false,
      persistent: true,
    );
  }

  Future<bool> restoreSession() async {
    StoredAuthSession? storedSession;
    try {
      storedSession = await _tokenStore.read();
    } on Object {
      _session.clear();
      return false;
    }
    if (storedSession == null) return false;
    try {
      final status = await _repository
          .loadAccountStatus(
            accessToken: storedSession.accessToken,
          )
          .timeout(_sessionValidationTimeout);
      await _tokenStore.write(
        storedSession.accessToken,
        profileComplete: status.profileComplete,
        onboardingComplete: status.onboardingComplete,
      );
      _session.establish(
        storedSession.accessToken,
        profileComplete: status.profileComplete,
        onboardingComplete: status.onboardingComplete,
        persistent: true,
      );
      return true;
    } on AuthRequestException catch (error) {
      if (error.statusCode != 401) {
        _session.establish(
          storedSession.accessToken,
          profileComplete: storedSession.profileComplete,
          onboardingComplete: storedSession.onboardingComplete,
          persistent: true,
        );
        return true;
      }
      await _tokenStore.delete();
      _session.clear();
      return false;
    } on Object {
      _session.establish(
        storedSession.accessToken,
        profileComplete: storedSession.profileComplete,
        onboardingComplete: storedSession.onboardingComplete,
        persistent: true,
      );
      return true;
    }
  }

  Future<void> logout() async {
    final accessToken = _session.accessToken;
    try {
      if (accessToken != null) {
        await _repository.logout(accessToken: accessToken);
      }
    } on Object {
      // Local logout must still complete when the network/server is unavailable.
    } finally {
      try {
        await _tokenStore.delete();
      } finally {
        _session.clear();
      }
    }
  }

  Future<void> markOnboardingComplete() async {
    final accessToken = _session.accessToken;
    if (accessToken == null) return;
    _session.markOnboardingComplete();
    if (_session.isPersistent) {
      await _tokenStore.write(
        accessToken,
        profileComplete: true,
        onboardingComplete: true,
      );
    }
  }

  Future<void> completeSocialProfile({
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    final accessToken = _session.accessToken;
    if (accessToken == null) {
      throw StateError('An authenticated session is required.');
    }
    final status = await _repository.completeSocialProfile(
      accessToken: accessToken,
      username: username,
      firstName: firstName,
      lastName: lastName,
    );
    if (!status.profileComplete) {
      throw const FormatException('The updated profile is still incomplete.');
    }
    _session.markProfileComplete();
    if (_session.isPersistent) {
      await _tokenStore.write(
        accessToken,
        profileComplete: true,
        onboardingComplete: status.onboardingComplete,
      );
    }
  }

  Future<AuthAccountStatus> _establishValidated(
    String accessToken, {
    required bool persist,
  }) async {
    final status = await _repository.loadAccountStatus(
      accessToken: accessToken,
    );
    if (persist) {
      await _tokenStore.write(
        accessToken,
        profileComplete: status.profileComplete,
        onboardingComplete: status.onboardingComplete,
      );
    } else {
      await _tokenStore.delete();
    }
    _session.establish(
      accessToken,
      profileComplete: status.profileComplete,
      onboardingComplete: status.onboardingComplete,
      persistent: persist,
    );
    return status;
  }
}
