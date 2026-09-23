import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_response.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';

/// Exchanges a Google SDK ID token for a 1Touch bearer access token.
class ApiGoogleAuthRepository implements AuthRepository {
  ApiGoogleAuthRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

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
  Future<EmailCodeChallenge> requestSignUpEmailCode({
    required String email,
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
        'purpose': 'signup',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthRequestException(
        statusCode: response.statusCode,
        message: _responseDetail(
          response.body,
          fallback: 'Unable to send a verification code.',
        ),
      );
    }

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return EmailCodeChallenge.fromJson(decoded);
  }

  @override
  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
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
        'first_name': firstName,
        'last_name': lastName,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthRequestException(
        statusCode: response.statusCode,
        message: _responseDetail(
          response.body,
          fallback: 'Unable to create the account.',
        ),
      );
    }

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return ApiGoogleAuthResponse.fromJson(decoded).accessToken;
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

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: null);
    return ApiGoogleAuthResponse.fromJson(decoded).accessToken;
  }

  static String _responseDetail(
    String responseBody, {
    required String fallback,
  }) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        if (detail is List) {
          final messages = detail
              .whereType<Map>()
              .map((item) => item['msg'])
              .whereType<String>()
              .map((message) => message.trim())
              .where((message) => message.isNotEmpty)
              .toList(growable: false);
          if (messages.isNotEmpty) return messages.join(' ');
        }
      }
    } on FormatException {
      // Non-JSON error bodies use the safe fallback below.
    }
    return fallback;
  }
}
