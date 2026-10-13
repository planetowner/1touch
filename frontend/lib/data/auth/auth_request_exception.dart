import 'package:http/http.dart' as http;

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

String authRequestErrorMessage(Object error, {required String fallback}) {
  if (error is http.ClientException) {
    return 'Please check your connection and try again.';
  }
  if (error is! AuthRequestException) return fallback;
  if (error.statusCode == 429) {
    return 'Too many requests. Please try again later.';
  }
  if (error.statusCode >= 500) {
    return 'The service is temporarily unavailable. Please try again later.';
  }
  if (error.statusCode == 401 &&
      error.message == 'Invalid email, username, or password') {
    return 'Your email, username, or password is incorrect.';
  }
  // 서버 설정명이나 검증 내부 정보 대신, 사용자가 해결할 수 있는 오류만 안내해요.
  return switch (error.message) {
    'Invalid verification code. Try again.' ||
    'This code has expired. Send a new code.' ||
    "This code can't be used. Request a new code." ||
    'Too many incorrect attempts. Send a new code.' ||
    'Email, username, or nickname is already registered' =>
      error.message,
    _ => fallback,
  };
}
