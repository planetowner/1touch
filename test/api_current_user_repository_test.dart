import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';

void main() {
  test('requests and maps the authenticated current user', () async {
    final repository = ApiCurrentUserRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/users/me');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_profileJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {
        'Authorization': 'Bearer session-token',
      },
    );

    final profile = await repository.load();

    expect(profile.userId, 1);
    expect(profile.username, 'planetowner');
    expect(profile.displayName, 'Planet Owner');
    expect(profile.favoriteTeamId, 83);
    expect(
      profile.avatarUri,
      Uri.parse('https://api.1touch.football/v1/users/1/avatar'),
    );
  });

  test('supports a trailing base-URI slash', () async {
    final repository = ApiCurrentUserRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/users/me');
        return http.Response(jsonEncode(_profileJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    expect((await repository.load()).username, 'planetowner');
  });

  test('surfaces non-successful HTTP responses', () async {
    final repository = ApiCurrentUserRepository(
      client: MockClient((_) async => http.Response('Unauthorized', 401)),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    await expectLater(repository.load(), throwsA(isA<http.ClientException>()));
  });

  test('rejects malformed JSON and non-object response roots', () async {
    final responses = [
      http.Response('{', 200),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiCurrentUserRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    await expectLater(repository.load(), throwsFormatException);
    await expectLater(repository.load(), throwsFormatException);
  });
}

Map<String, dynamic> _profileJson() {
  return {
    'user_id': 1,
    'username': 'planetowner',
    'first_name': 'Planet',
    'last_name': 'Owner',
    'email': 'owner@example.com',
    'avatar_url': '/v1/users/1/avatar',
    'favorite_team_id': 83,
    'created_at': '2026-09-01T14:00:00Z',
    'onboarding_complete': true,
  };
}
