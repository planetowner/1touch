import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthTokenStore {
  Future<StoredAuthSession?> read();
  Future<void> write(
    String accessToken, {
    required bool profileComplete,
    required bool onboardingComplete,
  });
  Future<void> delete();
}

class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.profileComplete,
    required this.onboardingComplete,
  });

  final String accessToken;
  final bool profileComplete;
  final bool onboardingComplete;
}

class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _accessTokenKey = 'onetouch_access_token';
  static const _profileCompleteKey = 'onetouch_profile_complete';
  static const _onboardingCompleteKey = 'onetouch_onboarding_complete';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthSession?> read() async {
    final accessToken = (await _storage.read(key: _accessTokenKey))?.trim();
    if (accessToken == null || accessToken.isEmpty) return null;
    final profileComplete = await _storage.read(key: _profileCompleteKey);
    final onboardingComplete = await _storage.read(key: _onboardingCompleteKey);
    return StoredAuthSession(
      accessToken: accessToken,
      profileComplete: profileComplete == 'true',
      onboardingComplete: onboardingComplete == 'true',
    );
  }

  @override
  Future<void> write(
    String accessToken, {
    required bool profileComplete,
    required bool onboardingComplete,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(
      key: _profileCompleteKey,
      value: profileComplete.toString(),
    );
    await _storage.write(
      key: _onboardingCompleteKey,
      value: onboardingComplete.toString(),
    );
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _profileCompleteKey);
    await _storage.delete(key: _onboardingCompleteKey);
  }
}
