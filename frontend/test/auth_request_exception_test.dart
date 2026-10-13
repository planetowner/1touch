import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  const fallback = 'Unable to verify the code. Please try again.';

  test('authentication errors show localized next steps without server details',
      () {
    for (final (error, expected) in [
      (
        const AuthRequestException(
            statusCode: 401, message: 'Invalid email, username, or password'),
        '이메일·아이디 또는 비밀번호가 올바르지 않아요.'
      ),
      (http.ClientException('Connection refused'), '연결 상태를 확인하고 다시 시도해 주세요.'),
      (
        const AuthRequestException(statusCode: 401, message: 'Expired token'),
        '인증번호를 확인하지 못했어요. 다시 시도해 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 429, message: 'Too many authentication requests'),
        '요청이 너무 많아요. 잠시 후 다시 시도해주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 503,
            message: 'Service configuration missing: SES_SMTP_PASSWORD'),
        '일시적인 문제가 생겼어요. 잠시 후 다시 시도해 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 422,
            message: 'Value error, internal validation detail'),
        '인증번호를 확인하지 못했어요. 다시 시도해 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400, message: 'Invalid verification code. Try again.'),
        '인증번호가 올바르지 않아요. 다시 입력해 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400,
            message: 'This code has expired. Send a new code.'),
        '인증번호가 만료됐어요. 새 인증번호를 받아 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400,
            message: 'Too many incorrect attempts. Send a new code.'),
        '인증번호 입력 횟수를 초과했어요. 새 인증번호를 받아 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400,
            message: "This code can't be used. Request a new code."),
        '이 인증번호는 사용할 수 없어요. 새 인증번호를 받아 주세요.'
      ),
      (StateError('Socket failed'), '인증번호를 확인하지 못했어요. 다시 시도해 주세요.'),
    ]) {
      final message = authRequestErrorMessage(error, fallback: fallback);
      expect(translateMessage(const Locale('ko'), message), expected);
      for (final locale in appSupportedLocales
          .where((locale) => locale.languageCode != 'en')) {
        expect(translateMessage(locale, message), isNot(message));
      }
    }
  });
}
