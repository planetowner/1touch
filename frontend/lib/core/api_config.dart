/// Development API settings supplied with `--dart-define-from-file`.
///
/// Dart defines are compiled into the app and are not secure token storage.
/// Replace `API_SESSION_TOKEN` with the authenticated session source before
/// production API providers are enabled.
class ApiConfig {
  ApiConfig._({
    required this.baseUri,
    required this.requestHeaders,
    required this.sessionToken,
  });

  final Uri baseUri;
  final Map<String, String> requestHeaders;
  final String? sessionToken;

  /// Temporary API smoke-test bypass while startup authentication is mocked.
  /// Remove this flag when the real authenticated session controls routing.
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

  factory ApiConfig.unauthenticatedFromEnvironment() {
    const baseUri = String.fromEnvironment('API_BASE_URI');
    return ApiConfig.unauthenticated(baseUri: baseUri);
  }

  factory ApiConfig.unauthenticated({required String baseUri}) {
    return ApiConfig._(
      baseUri: _parseBaseUri(baseUri),
      requestHeaders: const {},
      sessionToken: null,
    );
  }

  factory ApiConfig.fromValues({
    required String baseUri,
    required String sessionToken,
  }) {
    final normalizedBaseUri = _parseBaseUri(baseUri);
    final normalizedToken = sessionToken.trim();
    if (normalizedToken.isEmpty) {
      throw StateError('API_SESSION_TOKEN is not configured.');
    }

    return ApiConfig._(
      baseUri: normalizedBaseUri,
      requestHeaders: Map.unmodifiable({
        'Authorization': 'Bearer $normalizedToken',
      }),
      sessionToken: normalizedToken,
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
