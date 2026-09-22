import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';

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

  test('posts username and password without changing the password', () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/auth/login');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'username': 'member',
          'password': ' Password123 ',
        });
        return http.Response(
          jsonEncode({'access_token': 'password-session'}),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    final accessToken = await repository.signInWithPassword(
      username: ' member ',
      password: ' Password123 ',
    );

    expect(accessToken, 'password-session');
  });

  test('requests a signup email code and parses its challenge', () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/auth/email/code');
        expect(jsonDecode(request.body), {
          'email': 'member@example.com',
          'purpose': 'signup',
        });
        return http.Response(
          jsonEncode({
            'challenge_id': 'c' * 40,
            'expires_in': 600,
          }),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    final challenge = await repository.requestSignUpEmailCode(
      email: ' member@example.com ',
    );

    expect(challenge.challengeId, 'c' * 40);
    expect(challenge.expiresInSeconds, 600);
  });

  test('preserves the backend detail when an email-code request fails',
      () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Verification email could not be sent'}),
          502,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    await expectLater(
      repository.requestSignUpEmailCode(email: 'member@example.com'),
      throwsA(
        isA<AuthRequestException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.message,
              'message',
              'Verification email could not be sent',
            ),
      ),
    );
  });

  test('reads FastAPI validation messages for email-code failures', () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {'msg': 'value is not a valid email address'},
            ],
          }),
          422,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    await expectLater(
      repository.requestSignUpEmailCode(email: 'invalid'),
      throwsA(
        isA<AuthRequestException>().having(
          (error) => error.displayMessage,
          'displayMessage',
          'value is not a valid email address (422)',
        ),
      ),
    );
  });

  test('registers an email account and returns its access token', () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/auth/email/register');
        expect(jsonDecode(request.body), {
          'challenge_id': 'c' * 40,
          'code': '373262',
          'password': 'Password123',
          'username': 'member',
          'first_name': 'First',
          'last_name': 'Last',
        });
        return http.Response(
          jsonEncode({
            'access_token': 'email-session-token',
            'token_type': 'bearer',
          }),
          201,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    final accessToken = await repository.registerWithEmail(
      challengeId: 'c' * 40,
      code: '373262',
      password: 'Password123',
      username: 'member',
      firstName: 'First',
      lastName: 'Last',
    );

    expect(accessToken, 'email-session-token');
  });

  test('preserves backend detail when email registration fails', () async {
    final repository = ApiGoogleAuthRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': 'Invalid, expired, or exhausted verification code',
          }),
          400,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    );

    await expectLater(
      repository.registerWithEmail(
        challengeId: 'c' * 40,
        code: '000000',
        password: 'Password123',
        username: 'member',
        firstName: 'First',
        lastName: 'Last',
      ),
      throwsA(
        isA<AuthRequestException>().having(
          (error) => error.displayMessage,
          'displayMessage',
          'Invalid, expired, or exhausted verification code (400)',
        ),
      ),
    );
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
