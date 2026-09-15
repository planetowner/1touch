import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/players/api/api_player_club_history_repository.dart';

void main() {
  test('requests, maps, and caches a player club history', () async {
    var requests = 0;
    final repository = ApiPlayerClubHistoryRepository(
      client: MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/players/4313/club-history');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_historyJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final first = await repository.loadForPlayer(4313);
    final second = await repository.loadForPlayer(4313);

    expect(second, same(first));
    expect(requests, 1);
    expect(first.playerId, 4313);
    expect(first.clubs.map((club) => club.teamId), [2708, 6, 3321]);
    expect(first.clubs.first.teamName, 'Los Angeles FC');
    expect(first.clubs.first.startDate, DateTime.utc(2025, 8, 6));
    expect(first.clubs.first.endDate, isNull);
    expect(first.clubs.last.startDate, isNull);
    expect(first.clubs.last.teamImage, isNull);
    expect(repository.cachedForPlayer(4313), same(first));
    expect(() => first.clubs.clear(), throwsUnsupportedError);
    expect(
      () => repository.cachedHistories.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('accepts a successful empty history and a trailing base slash',
      () async {
    final repository = ApiPlayerClubHistoryRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/players/4313/club-history');
        return http.Response(
          jsonEncode({'player_id': 4313, 'clubs': []}),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    expect((await repository.loadForPlayer(4313)).clubs, isEmpty);
  });

  test('rejects a non-positive player ID before requesting', () async {
    var requests = 0;
    final repository = ApiPlayerClubHistoryRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.loadForPlayer(0), throwsRangeError);
    expect(requests, 0);
  });

  test('rejects HTTP and malformed responses without caching', () async {
    final mismatched = _historyJson()..['player_id'] = 997;
    final missingNullable = _historyJson();
    ((missingNullable['clubs'] as List).first as Map<String, dynamic>)
        .remove('start_date');
    final invalidDate = _historyJson();
    ((invalidDate['clubs'] as List).first
        as Map<String, dynamic>)['start_date'] = '2025-02-30';
    final invalidImage = _historyJson();
    ((invalidImage['clubs'] as List).first
        as Map<String, dynamic>)['team_image'] = '/team.png';
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(mismatched), 200),
      http.Response(jsonEncode(missingNullable), 200),
      http.Response(jsonEncode(invalidDate), 200),
      http.Response(jsonEncode(invalidImage), 200),
    ];
    var index = 0;
    final repository = ApiPlayerClubHistoryRepository(
      client: MockClient((_) async => responses[index++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.loadForPlayer(4313),
      throwsA(isA<http.ClientException>()),
    );
    for (var i = 1; i < responses.length; i++) {
      await expectLater(
        repository.loadForPlayer(4313),
        throwsFormatException,
      );
    }
    expect(repository.cachedHistories.value, isEmpty);
  });
}

Map<String, dynamic> _historyJson() => {
      'player_id': 4313,
      'clubs': [
        {
          'team_id': 2708,
          'team_name': 'Los Angeles FC',
          'team_image': 'https://cdn.sportmonks.com/images/la-fc.png',
          'start_date': '2025-08-06',
          'end_date': null,
        },
        {
          'team_id': 6,
          'team_name': 'Tottenham Hotspur',
          'team_image': 'https://cdn.sportmonks.com/images/tottenham.png',
          'start_date': '2015-08-28',
          'end_date': '2025-08-06',
        },
        {
          'team_id': 3321,
          'team_name': null,
          'team_image': null,
          'start_date': null,
          'end_date': '2015-08-28',
        },
      ],
    };
