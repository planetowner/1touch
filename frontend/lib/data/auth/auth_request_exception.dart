import 'package:http/http.dart' as http;
import 'package:onetouch/l10n/messages.dart';

class AuthRequestException implements Exception {
  const AuthRequestException({
    required this.statusCode,
    this.code,
  });

  final int statusCode;
  final String? code;

  bool get isVerificationCodeError =>
      statusCode == 400 && verificationCodeErrorMessages.containsKey(code);

  @override
  String toString() => 'AuthRequestException: $code ($statusCode)';
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
  // 서버 설정명이나 검증 내부 정보 대신, 사용자가 해결할 수 있는 오류만 안내해요.
  return authErrorMessages[error.code] ?? fallback;
}
