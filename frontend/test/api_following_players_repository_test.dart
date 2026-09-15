import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/players/api/api_following_players_repository.dart';

void main() {
  test('loads, maps, and caches players in backend order', () async {
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/users/me/following/players');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_followingJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final players = await repository.load();

    expect(players.map((player) => player.playerId), [268, 832]);
    expect(players.first.name, 'First Player');
    expect(players.last.imagePath, isNull);
    expect(repository.cachedPlayers.value, same(players));
    expect(() => players.clear(), throwsUnsupportedError);
  });

  test('PUT replaces the order and then re-fetches authoritative players',
      () async {
    var requestIndex = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((request) async {
        requestIndex++;
        expect(request.url.path, '/v1/users/me/following/players');
        expect(request.headers['Authorization'], 'Bearer session-token');
        if (requestIndex == 1) {
          expect(request.method, 'PUT');
          expect(request.headers['Accept'], 'application/json');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'player_ids': [832, 268],
          });
          return http.Response(jsonEncode({'ok': true}), 200);
        }

        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({
            'items': _followingJson()['items']!.reversed.toList(),
          }),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final players = await repository.replaceFollowing([832, 268]);

    expect(requestIndex, 2);
    expect(players.map((player) => player.playerId), [832, 268]);
    expect(repository.cachedPlayers.value, same(players));
  });

  test('supports clearing the list', () async {
    var requestIndex = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((request) async {
        requestIndex++;
        if (request.method == 'PUT') {
          expect(jsonDecode(request.body), {'player_ids': <int>[]});
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(jsonEncode({'items': []}), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    expect(await repository.replaceFollowing(const []), isEmpty);
    expect(requestIndex, 2);
  });

  test('accepts exactly 1000 unique positive player IDs', () async {
    final ids = List<int>.generate(1000, (index) => index + 1);
    var requestIndex = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((request) async {
        requestIndex++;
        if (request.method == 'PUT') {
          expect((jsonDecode(request.body)['player_ids'] as List).length, 1000);
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(jsonEncode({'items': []}), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await repository.replaceFollowing(ids);
    expect(requestIndex, 2);
  });

  test('rejects invalid update IDs before making a request', () async {
    var requests = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.replaceFollowing([0]), throwsRangeError);
    await expectLater(
      repository.replaceFollowing([268, 268]),
      throwsArgumentError,
    );
    await expectLater(
      repository.replaceFollowing(
        List<int>.generate(1001, (index) => index + 1),
      ),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects failed updates without re-fetching or changing the cache',
      () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode({'ok': false}), 200),
      http.Response(jsonEncode([]), 200),
    ];
    var requestIndex = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        return responses[requestIndex++];
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.replaceFollowing([268]),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.replaceFollowing([268]),
      throwsFormatException,
    );
    await expectLater(
      repository.replaceFollowing([268]),
      throwsFormatException,
    );
    expect(requestIndex, 3);
    expect(repository.cachedPlayers.value, isEmpty);
  });

  test('rejects failed or malformed GET responses without changing the cache',
      () async {
    final malformed = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(
        jsonEncode({
          'items': [
            {'player_id': 0, 'name': 'Invalid', 'image_path': null},
          ],
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'items': [
            {'player_id': 268, 'name': '  ', 'image_path': null},
          ],
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'items': [
            {'player_id': 268, 'name': 'One', 'image_path': null},
            {'player_id': 268, 'name': 'One Again', 'image_path': null},
          ],
        }),
        200,
      ),
    ];
    var requestIndex = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((_) async => malformed[requestIndex++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.load(), throwsA(isA<http.ClientException>()));
    for (var index = 1; index < malformed.length; index++) {
      await expectLater(repository.load(), throwsFormatException);
    }
    expect(repository.cachedPlayers.value, isEmpty);
  });

  test('does not overwrite an existing cache when post-update GET fails',
      () async {
    var requestIndex = 0;
    final repository = ApiFollowingPlayersRepository(
      client: MockClient((request) async {
        requestIndex++;
        if (requestIndex == 1) {
          return http.Response(jsonEncode(_followingJson()), 200);
        }
        if (requestIndex == 2) {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('Unavailable', 503);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );
    final initial = await repository.load();

    await expectLater(
      repository.replaceFollowing([832]),
      throwsA(isA<http.ClientException>()),
    );
    expect(repository.cachedPlayers.value, same(initial));
  });
}

Map<String, dynamic> _followingJson() => {
      'items': [
        {
          'player_id': 268,
          'name': 'First Player',
          'image_path': 'https://cdn.example.com/268.png',
        },
        {
          'player_id': 832,
          'name': 'Second Player',
          'image_path': null,
        },
      ],
    };
