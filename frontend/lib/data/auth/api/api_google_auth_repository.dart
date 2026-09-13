import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/auth/api/api_google_auth_response.dart';
import 'package:onetouch/data/auth/auth_repository.dart';

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

    final uri = _apiBaseUri.resolve('auth/google');
    final response = await _client.post(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id_token': normalizedIdToken}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Google authentication failed with status ${response.statusCode}.',
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
}
