import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/messages.dart';

void main() {
  const fallback = 'Unable to verify the code. Please try again.';

  test(
      'all authentication codes retain English and three existing translations',
      () {
    for (final entry in authErrorMessages.entries) {
      final message = authRequestErrorMessage(
          AuthRequestException(statusCode: 400, code: entry.key),
          fallback: fallback);
      expect(message, entry.value);
      final translations = appMessages[message]!;
      expect(translateMessage(const Locale('en'), message), message);
      expect(translateMessage(const Locale('ko'), message), translations.ko);
      expect(translateMessage(const Locale('ja'), message), translations.ja);
      expect(translateMessage(const Locale('zh'), message), translations.zh);
      expect([translations.ko, translations.ja, translations.zh],
          everyElement(allOf(isNotEmpty, isNot(message))));
    }
  });

  test('only known verification failures return to code entry', () {
    for (final code in verificationCodeErrorMessages.keys) {
      expect(
          AuthRequestException(statusCode: 400, code: code)
              .isVerificationCodeError,
          isTrue);
      expect(
          AuthRequestException(statusCode: 503, code: code)
              .isVerificationCodeError,
          isFalse);
    }
    for (final code in [null, 'unknown_error', 'registration_conflict']) {
      expect(
          AuthRequestException(statusCode: 400, code: code)
              .isVerificationCodeError,
          isFalse);
    }
  });

  test('authentication errors show localized next steps without server details',
      () {
    for (final (error, expected) in [
      (
        const AuthRequestException(
            statusCode: 401, code: 'invalid_credentials'),
        '이메일·아이디 또는 비밀번호가 올바르지 않아요.'
      ),
      (http.ClientException('Connection refused'), '연결 상태를 확인하고 다시 시도해 주세요.'),
      (
        const AuthRequestException(statusCode: 401, code: 'unknown_error'),
        '인증번호를 확인하지 못했어요. 다시 시도해 주세요.'
      ),
      (
        const AuthRequestException(statusCode: 429, code: 'auth_rate_limited'),
        '요청이 너무 많아요. 잠시 후 다시 시도해주세요.'
      ),
      (
        const AuthRequestException(statusCode: 503, code: 'unknown_error'),
        '일시적인 문제가 생겼어요. 잠시 후 다시 시도해 주세요.'
      ),
      (
        const AuthRequestException(statusCode: 422, code: 'unknown_error'),
        '인증번호를 확인하지 못했어요. 다시 시도해 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400, code: 'verification_code_invalid'),
        '인증번호가 올바르지 않아요. 다시 입력해 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400, code: 'verification_code_expired'),
        '인증번호가 만료됐어요. 새 인증번호를 받아 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400, code: 'verification_code_attempts_exceeded'),
        '인증번호 입력 횟수를 초과했어요. 새 인증번호를 받아 주세요.'
      ),
      (
        const AuthRequestException(
            statusCode: 400, code: "verification_code_unusable"),
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
