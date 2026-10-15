import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_response.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/registration_field.dart';

/// 소셜·비밀번호 인증과 이메일 인증번호 요청을 같은 API로 처리해요.
class ApiGoogleAuthRepository implements AuthRepository, LogoutAuthRepository {
  ApiGoogleAuthRepository({required ApiClient api, String Function()? locale})
      : _api = api,
        _locale = locale;

  final ApiClient _api;
  final String Function()? _locale;

  @override
  Future<bool> isRegistrationValueAvailable({
    required RegistrationField field,
    required String value,
  }) async {
    final response = await _api.post(
      _api.baseUri.resolve('auth/registration/availability'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'field': field.apiValue, 'value': value}),
    );
    _ensureSuccess(response);
    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return decoded['available'] as bool;
  }

  @override
  Future<String> signInWithSocial({
    required LoginProvider provider,
    required Map<String, String> credentials,
  }) =>
      _postForAccessToken('auth/${provider.name}', credentials);

  @override
  Future<String> signInWithGoogle({required String idToken}) async {
    final normalizedIdToken = idToken.trim();
    if (normalizedIdToken.isEmpty) {
      throw ArgumentError.value(idToken, 'idToken', 'must not be empty');
    }

    return _postForAccessToken(
      'auth/google',
      {'id_token': normalizedIdToken},
    );
  }

  @override
  Future<String> signInWithPassword({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw ArgumentError.value(username, 'username', 'must not be empty');
    }
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }

    return _postForAccessToken(
      'auth/login',
      {'username': normalizedUsername, 'password': password},
    );
  }

  @override
  Future<EmailCodeChallenge> requestEmailCode({
    required String email,
    EmailCodePurpose purpose = EmailCodePurpose.signup,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw ArgumentError.value(email, 'email', 'must not be empty');
    }

    final uri = _api.baseUri.resolve('auth/email/code');
    final response = await _api.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': normalizedEmail,
        'purpose': purpose.apiValue,
        // 최초 발송과 재전송 모두 현재 앱 언어를 사용해요.
        'language': _locale?.call() ?? 'en',
      }),
    );
    _ensureSuccess(response);

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return EmailCodeChallenge.fromJson(decoded);
  }

  @override
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String password,
  }) async {
    final response = await _api.post(
      _api.baseUri.resolve('auth/email/reset-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'challenge_id': challengeId,
        'code': code,
        'password': password,
      }),
    );
    _ensureSuccess(response);
    _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
  }

  @override
  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final uri = _api.baseUri.resolve('auth/email/register');
    final response = await _api.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'challenge_id': challengeId,
        'code': code,
        'password': password,
        'username': username,
        'display_name': displayName,
      }),
    );
    _ensureSuccess(response);

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return ApiGoogleAuthResponse.fromJson(decoded).accessToken;
  }

  @override
  Future<void> logout() async {
    final response = await _api.post(_api.baseUri.resolve('auth/logout'));
    _ensureSuccess(response);
  }

  Future<String> _postForAccessToken(
    String path,
    Map<String, String> body,
  ) async {
    final uri = _api.baseUri.resolve(path);
    final response = await _api.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    _ensureSuccess(response);
    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return ApiGoogleAuthResponse.fromJson(decoded).accessToken;
  }

  void _ensureSuccess(http.Response response) {
    // 모든 인증 요청에서 HTTP 상태와 오류 코드를 같은 규칙으로 보존해요.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthRequestException(
        statusCode: response.statusCode,
        code: _api.errorCode(response),
      );
    }
  }
}
