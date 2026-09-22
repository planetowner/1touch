import 'package:onetouch/core/api_config.dart';

class AuthSession {
  String? _accessToken;
  bool _profileComplete = false;
  bool _onboardingComplete = false;
  bool _persistent = false;

  bool get isAuthenticated => _accessToken != null;
  bool get profileComplete => _profileComplete;
  bool get onboardingComplete => _onboardingComplete;
  bool get isPersistent => _persistent;
  String? get accessToken => _accessToken;

  Map<String, String> get requestHeaders {
    final accessToken = _accessToken;
    if (accessToken == null) return const {};
    return Map.unmodifiable({
      'Authorization': 'Bearer $accessToken',
    });
  }

  void establish(
    String accessToken, {
    bool profileComplete = true,
    bool onboardingComplete = true,
    bool persistent = false,
  }) {
    final normalizedAccessToken = accessToken.trim();
    if (normalizedAccessToken.isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'must not be empty',
      );
    }
    _accessToken = normalizedAccessToken;
    _profileComplete = profileComplete;
    _onboardingComplete = onboardingComplete;
    _persistent = persistent;
    ApiConfig.setRuntimeAccessToken(normalizedAccessToken);
  }

  void clear() {
    _accessToken = null;
    _profileComplete = false;
    _onboardingComplete = false;
    _persistent = false;
    ApiConfig.setRuntimeAccessToken(null);
  }

  void markOnboardingComplete() {
    if (!isAuthenticated) return;
    _profileComplete = true;
    _onboardingComplete = true;
  }

  void markProfileComplete() {
    if (!isAuthenticated) return;
    _profileComplete = true;
  }
}
