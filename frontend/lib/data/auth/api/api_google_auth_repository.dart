import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/auth/api/api_google_auth_response.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';

/// Exchanges a Google SDK ID token for a 1Touch bearer access token.
class ApiGoogleAuthRepository implements AuthRepository {
  ApiGoogleAuthRepository({
    required http.Client client,
    required Uri apiBaseUri,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri);

  final http.Client _client;
  final Uri _apiBaseUri;

  @override
  Future<String> signInWithGoogle({required String idToken}) async {
    final normalizedIdToken = idToken.trim();
    if (normalizedIdToken.isEmpty) {
      throw ArgumentError.value(idToken, 'idToken', 'must not be empty');
    }

    return _postForAccessToken(
      'auth/google',
      {'id_token': normalizedIdToken},
      failureLabel: 'Google authentication',
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
      failureLabel: 'Password authentication',
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

    final uri = _apiBaseUri.resolve('auth/email/code');
    final response = await _client.post(
      uri,
      headers: const {
        'Accept': 'application/json',
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

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the email-code response to be a JSON object.',
      );
    }
    return EmailCodeChallenge.fromJson(decoded);
  }

  Future<String> _postForAccessToken(
    String path,
    Map<String, String> body, {
    required String failureLabel,
  }) async {
    final uri = _apiBaseUri.resolve(path);
    final response = await _client.post(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        '$failureLabel failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the Google authentication response to be a JSON object.',
      );
    }
    return ApiGoogleAuthResponse.fromJson(decoded).accessToken;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
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
