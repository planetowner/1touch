import 'package:onetouch/models/profile_change_limit_exception.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';

void main() {
  test('restores the last validated account from local cache', () async {
    final store = MemoryLocalCacheStore();
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode(_profileJson()),
              200,
            )),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    await repository.loadAccount();
    final cached = await repository.loadCachedAccount();

    expect(cached?.username, 'planetowner');
    expect(cached?.favoriteTeamId, 83);
  });

  test('profile mutation replaces the cached account', () async {
    final store = MemoryLocalCacheStore();
    final updated = _profileJson()..['username'] = 'updated';
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          return http.Response(jsonEncode(updated), 200);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    await repository.updateProfile(
      username: 'updated',
      displayName: 'Planet Owner',
    );

    final cached = await repository.loadCachedAccount();
    expect(cached?.username, 'updated');
  });

  test('requests and maps the authenticated current user', () async {
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/users/me');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_profileJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {
                'Authorization': 'Bearer session-token',
              }),
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
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/users/me');
            return http.Response(jsonEncode(_profileJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    expect((await repository.load()).username, 'planetowner');
  });

  test('sends the nickname separately from the login ID', () async {
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'username': 'john_doe',
            'display_name': 'Planet Owner',
          });
          return http.Response(jsonEncode(_profileJson()), 200);
        }),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );
    await repository.updateProfile(
      username: 'john_doe',
      displayName: 'Planet Owner',
    );
  });

  test('social completion sends only nickname and keeps username null',
      () async {
    final store = MemoryLocalCacheStore();
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/v1/users/me/profile');
          expect(jsonDecode(request.body), {
            'display_name': 'Supporter',
          });
          return http.Response(
              jsonEncode(_profileJson()
                ..['username'] = null
                ..['display_name'] = 'Supporter'),
              200);
        }),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    await repository.updateProfile(
      displayName: 'Supporter',
    );
    expect((await repository.loadCachedAccount())?.username, isNull);
  });

  test('reports when the nickname change limit expires', () async {
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'detail': {
                'message': 'limit',
                'max_changes': 3,
                'window_days': 7,
                'available_at': '2026-10-13T12:00:00Z'
              }
            }),
            409)),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );
    await expectLater(
        repository.updateProfile(
          username: 'john_doe',
          displayName: 'Next',
        ),
        throwsA(isA<ProfileChangeLimitException>()
            .having((error) => error.maxChanges, 'maxChanges', 3)
            .having((error) => error.windowDays, 'windowDays', 7)));
  });

  test('reports a duplicate ID or nickname from profile updates', () async {
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response(
            jsonEncode({'detail': 'Username or nickname is already in use'}),
            409)),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );
    await expectLater(
        repository.updateProfile(
          username: 'john_doe',
          displayName: 'Maple',
        ),
        throwsA(isA<ProfileNameConflictException>()));
  });

  test('surfaces non-successful HTTP responses', () async {
    final repository = ApiCurrentUserRepository(
      api: ApiClient(
          client: MockClient((_) async => http.Response('Unauthorized', 401)),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
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
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(repository.load(), throwsFormatException);
    await expectLater(repository.load(), throwsFormatException);
  });
}

Map<String, dynamic> _profileJson() {
  return {
    'user_id': 1,
    'username': 'planetowner',
    'display_name': 'Planet Owner',
    'email': 'owner@example.com',
    'avatar_url': '/v1/users/1/avatar',
    'favorite_team_id': 83,
    'created_at': '2026-09-01T14:00:00Z',
    'onboarding_complete': true,
  };
}
