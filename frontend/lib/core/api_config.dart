/// API 주소와 선택적인 개발 세션을 실행 설정에서 읽어요.
class ApiConfig {
  ApiConfig._({
    required this.baseUri,
    required this.sessionToken,
  });

  final Uri baseUri;
  final String? sessionToken;

  /// 개발 세션으로 화면을 확인할 때만 온보딩을 건너뛰어요.
  static const bool skipOnboardingForDevelopment = bool.fromEnvironment(
    'API_SKIP_ONBOARDING',
  );

  factory ApiConfig.fromEnvironment() {
    const baseUri = String.fromEnvironment('API_BASE_URI');
    const sessionToken = String.fromEnvironment('API_SESSION_TOKEN');
    return ApiConfig.fromValues(
      baseUri: baseUri,
      sessionToken: sessionToken,
    );
  }

  factory ApiConfig.fromValues({
    required String baseUri,
    String sessionToken = '',
  }) {
    final normalizedBaseUri = _parseBaseUri(baseUri);
    final normalizedToken = sessionToken.trim();
    return ApiConfig._(
      baseUri: normalizedBaseUri,
      sessionToken: normalizedToken.isEmpty ? null : normalizedToken,
    );
  }

  static Uri _parseBaseUri(String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw StateError('API_BASE_URI is not configured.');
    }

    final uri = Uri.tryParse(normalizedValue);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException('Invalid API_BASE_URI: $normalizedValue');
    }

    final uriString = uri.toString();
    return uriString.endsWith('/') ? uri : Uri.parse('$uriString/');
  }
}
