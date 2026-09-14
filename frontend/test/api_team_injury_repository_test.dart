import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';

void main() {
  test('requests, maps, and caches the current team injury report', () async {
    var requestCount = 0;
    final repository = ApiTeamInjuryRepository(
      client: MockClient((request) async {
        requestCount++;
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/teams/83/injuries');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_reportJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(second, same(first));
    expect(first.teamId, 83);
    expect(first.seasonId, 25659);
    expect(first.players.single.injuries, hasLength(2));
    expect(repository.cachedForTeam(83), same(first));
    expect(requestCount, 1);
    expect(
      () => repository.cachedReports.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('supports a trailing base-URI slash and an empty player list', () async {
    final repository = ApiTeamInjuryRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/teams/83/injuries');
        return http.Response(
          jsonEncode(_reportJson(players: const [])),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    final report = await repository.loadForTeam(83);

    expect(report.players, isEmpty);
    expect(repository.cachedForTeam(83), same(report));
  });

  test('keeps different teams in separate cache entries', () async {
    final repository = ApiTeamInjuryRepository(
      client: MockClient((request) async {
        final teamId = int.parse(request.url.pathSegments[2]);
        return http.Response(jsonEncode(_reportJson(teamId: teamId)), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(19);

    expect(first.teamId, 83);
    expect(second.teamId, 19);
    expect(repository.cachedReports.value, hasLength(2));
  });

  test('surfaces unavailable, authentication, and server failures', () async {
    final responses = [
      http.Response('Not found', 404),
      http.Response('Unauthorized', 401),
      http.Response('Server error', 500),
    ];
    var requestCount = 0;
    final repository = ApiTeamInjuryRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(
        repository.loadForTeam(83),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(repository.cachedReports.value, isEmpty);
  });

  test('rejects malformed and mismatched responses without caching', () async {
    final responses = [
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_reportJson(teamId: 19)), 200),
      http.Response(
        jsonEncode({..._reportJson(), 'season_id': '25659'}),
        200,
      ),
    ];
    var requestCount = 0;
    final repository = ApiTeamInjuryRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(repository.loadForTeam(83), throwsFormatException);
    }
    expect(repository.cachedReports.value, isEmpty);
  });
}

Map<String, dynamic> _reportJson({
  int teamId = 83,
  List<Map<String, dynamic>>? players,
}) {
  return {
    'team_id': teamId,
    'season_id': 25659,
    'players': players ??
        [
          {
            'player_id': 101,
            'player_name': 'Player 101',
            'player_image': null,
            'jersey_number': null,
            'injuries': [
              {
                'sideline_id': 5001,
                'type_id': 2,
                'type_name': 'Muscle Injury',
                'start_date': '2026-09-01',
                'end_date': '2026-09-20',
              },
              {
                'sideline_id': 5002,
                'type_id': 3,
                'type_name': 'Knock',
                'start_date': '2026-08-15',
                'end_date': null,
              },
            ],
          },
        ],
  };
}
