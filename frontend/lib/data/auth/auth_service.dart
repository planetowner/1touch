import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/auth_token_store.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/registration_field.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';

const passwordGuideMessage =
    'Use 8–128 characters with at least one uppercase letter, one lowercase letter, and one number.';

bool isValidNewPassword(String value) =>
    newPasswordValidationMessage(value) == null;

String? newPasswordValidationMessage(String value) {
  if (value.isEmpty) return 'Enter your password.';
  // 가입·재설정 모두 원문을 그대로 세고, 기존처럼 길이를 먼저 확인해요.
  final length = value.runes.length;
  if (length < 8 || length > 128) return 'Use 8–128 characters.';
  if (!RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[a-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value)) {
    return 'Include at least one uppercase letter, one lowercase letter, and one number.';
  }
  return null;
}

String? passwordConfirmationValidationMessage(String value, String password) {
  if (value.isEmpty) return 'Enter your password again.';
  return value == password
      ? null
      : "The passwords don't match. Please check again.";
}

class AuthService {
  const AuthService({
    required GoogleIdentityService googleIdentityService,
    required AuthRepository repository,
    required AuthSession session,
    SocialIdentityService? socialIdentityService,
    AuthTokenStore? tokenStore,
    Future<void> Function()? clearLocalUserData,
    Future<void> Function()? onSessionEstablished,
    Future<void> Function()? beforeSessionCleared,
  })  : _googleIdentityService = googleIdentityService,
        _repository = repository,
        _session = session,
        _socialIdentityService = socialIdentityService,
        _tokenStore = tokenStore,
        _clearLocalUserData = clearLocalUserData,
        _onSessionEstablished = onSessionEstablished,
        _beforeSessionCleared = beforeSessionCleared;

  final GoogleIdentityService _googleIdentityService;
  final AuthRepository _repository;
  final AuthSession _session;
  final SocialIdentityService? _socialIdentityService;
  final AuthTokenStore? _tokenStore;
  final Future<void> Function()? _clearLocalUserData;
  final Future<void> Function()? _onSessionEstablished;
  final Future<void> Function()? _beforeSessionCleared;

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

  Future<bool> isRegistrationValueAvailable({
    required RegistrationField field,
    required String value,
  }) =>
      _repository.isRegistrationValueAvailable(field: field, value: value);

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
    required String displayName,
  }) async {
    final accessToken = await _repository.registerWithEmail(
      challengeId: challengeId,
      code: code,
      password: password,
      username: username,
      displayName: displayName,
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
      await _beforeSessionCleared?.call();
    } on Object {
      // Push cleanup must not prevent account logout.
    }
    try {
      final repository = _repository;
      if (_session.isAuthenticated && repository is LogoutAuthRepository) {
        await (repository as LogoutAuthRepository).logout();
      }
    } on Object {
      // A local logout must still work while the server is unreachable.
    } finally {
      await _tokenStore?.delete();
      await _clearLocalUserData?.call();
      _session.clear();
    }
  }

  Future<void> _establish(String accessToken) async {
    // A fresh sign-in must never inherit another account's local snapshots.
    await _clearLocalUserData?.call();
    _session.establish(accessToken);
    await _tokenStore?.write(
      _session.accessToken!,
      profileComplete: false,
      onboardingComplete: false,
    );
    try {
      await _onSessionEstablished?.call();
    } on Object {
      // Optional device registration must not turn login into a failure.
    }
  }
}
