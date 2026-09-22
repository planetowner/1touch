class AuthRequestException implements Exception {
  const AuthRequestException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  String get displayMessage => '$message ($statusCode)';

  @override
  String toString() => 'AuthRequestException: $displayMessage';
}
