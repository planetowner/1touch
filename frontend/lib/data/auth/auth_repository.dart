abstract interface class AuthRepository {
  Future<String> signInWithGoogle({required String idToken});
}
