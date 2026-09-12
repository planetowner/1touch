import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';

void main() {
  test('posts a Google ID token and returns the backend access token',
      () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/auth/google');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {'id_token': 'google-id-token'});
        return http.Response(
          jsonEncode({
            'access_token': 'backend-access-token',
            'token_type': 'bearer',
          }),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    final accessToken = await repository.signInWithGoogle(
      idToken: ' google-id-token ',
    );

    expect(accessToken, 'backend-access-token');
  });

  test('supports a trailing base-URI slash and any successful status',
      () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/auth/google');
        return http.Response(
          jsonEncode({'access_token': 'created-session'}),
          201,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
    );

    expect(
      await repository.signInWithGoogle(idToken: 'id-token'),
      'created-session',
    );
  });

  test('rejects an empty Google ID token before making a request', () async {
    var requestCount = 0;
    final repository = ApiGoogleAuthRepository(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
    );

    await expectLater(
      repository.signInWithGoogle(idToken: '   '),
      throwsArgumentError,
    );
    expect(requestCount, 0);
  });

  test('surfaces unsuccessful HTTP responses', () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient((_) async => http.Response('Unauthorized', 401)),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
    );

    await expectLater(
      repository.signInWithGoogle(idToken: 'id-token'),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('rejects malformed or incomplete successful responses', () async {
    final responses = [
      http.Response('{', 200),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({}), 200),
      http.Response(jsonEncode({'access_token': '  '}), 200),
    ];
    var requestCount = 0;
    final repository = ApiGoogleAuthRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(
        repository.signInWithGoogle(idToken: 'id-token'),
        throwsFormatException,
      );
    }
  });
}
