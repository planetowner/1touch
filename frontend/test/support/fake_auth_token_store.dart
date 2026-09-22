import 'package:onetouch/data/auth/auth_token_store.dart';

class FakeAuthTokenStore implements AuthTokenStore {
  StoredAuthSession? value;

  @override
  Future<StoredAuthSession?> read() async => value;

  @override
  Future<void> write(
    String accessToken, {
    required bool profileComplete,
    required bool onboardingComplete,
  }) async =>
      value = StoredAuthSession(
        accessToken: accessToken,
        profileComplete: profileComplete,
        onboardingComplete: onboardingComplete,
      );

  @override
  Future<void> delete() async => value = null;
}
