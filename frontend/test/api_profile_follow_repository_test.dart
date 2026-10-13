import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_profile_follow_repository.dart';
import 'package:onetouch/models/profile_follow.dart';

void main() {
  test('counts use the current session and keep zero distinct from failures',
      () async {
    var token = 'first';
    final repository = _repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/users/me/follow/counts');
      expect(request.url.queryParameters, isEmpty);
      expect(request.headers['Authorization'], 'Bearer $token');
      return http.Response('{"follower_count":0,"following_count":3}', 200);
    }, token: () => token);
    expect((await repository.loadCounts()).followers, 0);
    token = 'second';
    expect((await repository.loadCounts()).following, 3);

    await expectLater(
      _repository((_) async => http.Response('{}', 500)).loadCounts(),
      throwsA(isA<http.ClientException>()),
    );
    for (final response in [
      http.Response('{"follower_count":-1,"following_count":0}', 200),
      http.Response('{"follower_count":0}', 200),
    ]) {
      await expectLater(
        _repository((_) async => response).loadCounts(),
        throwsFormatException,
      );
    }
  });

  test('both lists parse public profiles and validate pagination', () async {
    final paths = <String>[];
    final repository = _repository((request) async {
      paths.add(request.url.path);
      expect(request.method, 'GET');
      expect(request.url.queryParameters, {
        'limit': '20',
        'offset': '40',
        'sort': request.url.path.endsWith('followers') ? 'newest' : 'oldest'
      });
      return http.Response(
          jsonEncode({
            'items': [
              {
                'user_id': 2,
                'username': 'friend',
                'display_name': 'Friend',
                'avatar_url': '/v1/users/2/avatar',
                'following': true,
                'is_self': false,
                'author_deleted': false,
              },
              {
                'user_id': 3,
                'username': 'social',
                'display_name': null,
                'avatar_url': null,
                'following': false,
                'is_self': false,
                'author_deleted': false,
              },
            ],
            'limit': 20,
            'offset': 40,
          }),
          200);
    });
    for (final tab in ProfileFollowTab.values) {
      final users = await repository.loadUsers(
          tab: tab,
          sort: tab == ProfileFollowTab.followers
              ? ProfileFollowSort.newest
              : ProfileFollowSort.oldest,
          limit: 20,
          offset: 40);
      expect(users.map((user) => user.name), ['Friend', 'social']);
      expect(users.first.avatarUri.toString(),
          'https://example.com/v1/users/2/avatar');
      expect(users.last.avatarUri, isNull);
      expect(() => users.clear(), throwsUnsupportedError);
    }
    expect(paths, ['/v1/users/me/followers', '/v1/users/me/following']);
    await expectLater(
        repository.loadUsers(
            tab: ProfileFollowTab.followers,
            sort: ProfileFollowSort.newest,
            limit: 0),
        throwsRangeError);
    await expectLater(
        repository.loadUsers(
            tab: ProfileFollowTab.followers,
            sort: ProfileFollowSort.newest,
            offset: -1),
        throwsRangeError);
  });

  test('malformed list pages fail instead of appearing empty', () async {
    for (final page in [
      {'items': [], 'limit': 50, 'offset': 1},
      {'items': null, 'limit': 50, 'offset': 0},
      {
        'items': [1],
        'limit': 50,
        'offset': 0
      },
      {
        'items': [
          {'user_id': 1, 'display_name': 7}
        ],
        'limit': 50,
        'offset': 0,
      },
    ]) {
      await expectLater(
        _repository((_) async => http.Response(jsonEncode(page), 200))
            .loadUsers(
                tab: ProfileFollowTab.followers,
                sort: ProfileFollowSort.newest),
        throwsFormatException,
      );
    }
  });

  test('following removal uses the existing follow endpoint', () async {
    final repository = _repository((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/v1/users/9/follow');
      expect(request.headers['Authorization'], 'Bearer session');
      return http.Response('{"ok":true}', 200);
    });
    await repository.unfollow(9);
  });
}

ApiProfileFollowRepository _repository(
  Future<http.Response> Function(http.Request) handler, {
  String Function()? token,
}) =>
    ApiProfileFollowRepository(
      api: ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://example.com/v1/'),
        requestHeaders: () =>
            {'Authorization': 'Bearer ${token?.call() ?? 'session'}'},
      ),
    );
