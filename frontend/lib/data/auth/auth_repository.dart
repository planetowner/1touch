import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/login_provider.dart';

abstract interface class AuthRepository {
  Future<String> signInWithSocial({
    required LoginProvider provider,
    required Map<String, String> credentials,
  });

  Future<String> signInWithGoogle({required String idToken});

  Future<String> signInWithPassword({
    required String username,
    required String password,
  });

  Future<EmailCodeChallenge> requestEmailCode(
      {required String email,
      EmailCodePurpose purpose = EmailCodePurpose.signup});

  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String password,
  });

  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
  });
}
