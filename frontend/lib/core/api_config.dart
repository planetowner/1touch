import 'package:http/http.dart' as http;

/// Development API settings supplied with `--dart-define-from-file`.
///
/// Dart defines are compiled into the app and are not secure token storage.
/// `API_SESSION_TOKEN` is now only a skip-onboarding development fallback;
/// normal launches use the session restored from secure platform storage.
class ApiConfig {
  ApiConfig._({
    required this.baseUri,
    required this.requestHeaders,
    required this.sessionToken,
  });

  final Uri baseUri;
  final Map<String, String> requestHeaders;
  final String? sessionToken;

  static String? _runtimeAccessToken;

  /// The authenticated app session takes precedence over the development
  /// token. The latter is available only in the explicit onboarding bypass.
  static String? get currentAccessToken {
    final runtimeToken = _runtimeAccessToken;
    if (runtimeToken != null) return runtimeToken;
    if (!skipOnboardingForDevelopment) return null;
    const developmentToken = String.fromEnvironment('API_SESSION_TOKEN');
    final normalized = developmentToken.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static void setRuntimeAccessToken(String? accessToken) {
    final normalized = accessToken?.trim();
    _runtimeAccessToken =
        normalized == null || normalized.isEmpty ? null : normalized;
  }

  /// Injects the latest login token when each request is sent, so repositories
  /// do not retain the token that happened to exist at construction time.
  static http.Client sessionAwareClient([http.Client? inner]) =>
      _SessionAwareClient(inner ?? http.Client());

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

class _SessionAwareClient extends http.BaseClient {
  _SessionAwareClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.remove('Authorization');
    final accessToken = ApiConfig.currentAccessToken;
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
