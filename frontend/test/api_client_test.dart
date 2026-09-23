import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';
import 'package:onetouch/data/profile/api/api_profile_avatar_repository.dart';

void main() {
  test('login updates existing repositories and multipart requests', () async {
    final session = AuthSession();
    final requests = <http.Request>[];
    var loginCount = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Accept'], 'application/json');
        switch (request.url.path) {
          case '/v1/auth/login':
            return http.Response(
                jsonEncode({'access_token': 'session-${++loginCount}'}), 200);
          case '/v1/users/me':
            return http.Response(
                jsonEncode({
                  'user_id': 7,
                  'username': 'member',
                  'first_name': 'First',
                  'last_name': 'Last',
                  'email': null,
                  'avatar_url': null,
                  'favorite_team_id': 8,
                  'created_at': '2026-09-01T14:00:00Z',
                  'onboarding_complete': true,
                }),
                200);
          case '/v1/users/me/avatar':
            expect(request.headers['Content-Type'],
                startsWith('multipart/form-data;'));
            expect(request.body, contains('filename="avatar.png"'));
            return http.Response('{"avatar_url":"/v1/users/7/avatar"}', 200);
          default:
            fail('Unexpected request: ${request.url}');
        }
      }),
      baseUri: Uri.parse('https://example.test/v1'),
      requestHeaders: () => session.requestHeaders,
    );
    addTearDown(api.close);
    final profile = ApiCurrentUserRepository(api: api);
    final avatar = ApiProfileAvatarRepository(api: api);
    final auth = AuthService(
      googleIdentityService: _UnusedGoogleIdentityService(),
      repository: ApiGoogleAuthRepository(api: api),
      session: session,
    );

    await auth.signInWithPassword(username: 'member', password: 'password');
    expect(requests.first.headers['Authorization'], isNull);
    expect((await profile.load()).userId, 7);
    expect(requests.last.headers['Authorization'], 'Bearer session-1');

    await auth.signInWithPassword(username: 'member', password: 'password');
    await profile.load();
    expect(requests.last.headers['Authorization'], 'Bearer session-2');
    await avatar.upload(
        bytes: Uint8List.fromList([1, 2, 3]), filename: 'avatar.png');
    expect(requests.last.headers['Authorization'], 'Bearer session-2');
  });

  test('decodes UTF-8 objects and the backend list response', () {
    final api = _decodingClient();
    addTearDown(api.close);
    final response = http.Response.bytes(utf8.encode('{"name":"손흥민"}'), 200);
    expect(api.decodeJson<Map<String, dynamic>>(response), {'name': '손흥민'});
    expect(api.decodeJson<List<dynamic>>(http.Response('[1,2]', 200)), [1, 2]);
  });

  test('checks HTTP status before decoding and preserves expected statuses',
      () {
    final api = _decodingClient();
    addTearDown(api.close);
    expect(
      () => api
          .decodeJson<Map<String, dynamic>>(http.Response('Unauthorized', 401)),
      throwsA(isA<http.ClientException>()),
    );
    expect(
      () => api.decodeJson<Map<String, dynamic>>(http.Response('{}', 201)),
      throwsA(isA<http.ClientException>()),
    );
    expect(
        api.decodeJson<Map<String, dynamic>>(http.Response('{}', 201),
            expectedStatus: 201),
        isEmpty);
    for (final body in ['{', '[]', 'null']) {
      expect(
        () => api.decodeJson<Map<String, dynamic>>(http.Response(body, 200)),
        throwsFormatException,
      );
    }
  });
}

ApiClient _decodingClient() => ApiClient(
      client: MockClient((_) async => throw StateError('No request expected')),
      baseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: () => const {},
    );

class _UnusedGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String> authenticate() async =>
      throw StateError('No Google login expected');
}
