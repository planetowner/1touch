class ViewerCountryConfig {
  const ViewerCountryConfig._();

  static const String _environmentValue = String.fromEnvironment(
    'API_VIEWER_COUNTRY',
  );

  static String fromEnvironment() => normalize(_environmentValue);

  static String normalize(String value) {
    final normalized = value.trim().toUpperCase();
    if (!_isUppercaseIsoCode(normalized)) {
      throw FormatException(
        'API_VIEWER_COUNTRY must be an ISO 3166-1 alpha-2 country code.',
      );
    }
    return normalized;
  }

  static bool _isUppercaseIsoCode(String value) =>
      value.length == 2 &&
      value.codeUnits.every((codeUnit) => codeUnit >= 65 && codeUnit <= 90);
}
