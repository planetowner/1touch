class AuthSession {
  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;

  Map<String, String> get requestHeaders {
    final accessToken = _accessToken;
    if (accessToken == null) return const {};
    return Map.unmodifiable({
      'Authorization': 'Bearer $accessToken',
    });
  }

  void establish(String accessToken) {
    final normalizedAccessToken = accessToken.trim();
    if (normalizedAccessToken.isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'must not be empty',
      );
    }
    _accessToken = normalizedAccessToken;
  }

  void clear() => _accessToken = null;
}
