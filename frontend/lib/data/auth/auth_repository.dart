import 'package:onetouch/data/auth/auth_account_status.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';

abstract interface class AuthRepository {
  Future<String> signInWithGoogle({required String idToken});

  Future<String> signInWithPassword({
    required String username,
    required String password,
  });

  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email});

  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
  });

  Future<AuthAccountStatus> loadAccountStatus({required String accessToken});

  Future<AuthAccountStatus> completeSocialProfile({
    required String accessToken,
    required String username,
    required String firstName,
    required String lastName,
  });

  Future<void> logout({required String accessToken});
}
