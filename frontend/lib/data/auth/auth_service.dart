import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

class AuthService {
  const AuthService({
    required GoogleIdentityService googleIdentityService,
    required AuthRepository repository,
    required AuthSession session,
  })  : _googleIdentityService = googleIdentityService,
        _repository = repository,
        _session = session;

  final GoogleIdentityService _googleIdentityService;
  final AuthRepository _repository;
  final AuthSession _session;

  Future<void> signInWithGoogle() async {
    final idToken = await _googleIdentityService.authenticate();
    final accessToken = await _repository.signInWithGoogle(idToken: idToken);
    _session.establish(accessToken);
  }

  Future<void> signInWithPassword({
    required String username,
    required String password,
  }) async {
    final accessToken = await _repository.signInWithPassword(
      username: username,
      password: password,
    );
    _session.establish(accessToken);
  }

  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email}) =>
      _repository.requestSignUpEmailCode(email: email);
}
