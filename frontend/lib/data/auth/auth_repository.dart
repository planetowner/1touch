import 'package:onetouch/data/auth/email_code_challenge.dart';

abstract interface class AuthRepository {
  Future<String> signInWithGoogle({required String idToken});

  Future<String> signInWithPassword({
    required String username,
    required String password,
  });

  Future<EmailCodeChallenge> requestSignUpEmailCode({required String email});
}
