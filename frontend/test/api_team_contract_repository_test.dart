import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_repository.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';

void main() {
  test('requests, maps, and caches the current team contract roster', () async {
    var requestCount = 0;
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestCount++;
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/teams/83/contracts');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_rosterJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(second, same(first));
    expect(first.teamId, 83);
    expect(first.seasonId, 25659);
    expect(first.players.single.playerName, 'Contract Player');
    expect(first.players.single.endDate, DateTime.utc(2028, 6, 30));
    expect(repository.cachedForTeam(83), same(first));
    expect(requestCount, 1);
    expect(
      () => repository.cachedRosters.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('requests and caches an explicit historical season separately',
      () async {
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/teams/83/contracts');
            expect(request.url.queryParameters, {'season_id': '23621'});
            return http.Response(
              jsonEncode(_rosterJson(seasonId: 23621, isCurrent: false)),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final historical = await repository.loadForTeam(83, seasonId: 23621);

    expect(historical.seasonId, 23621);
    expect(historical.isCurrent, isFalse);
    expect(repository.cachedForTeam(83), isNull);
    expect(
      repository.cachedForTeam(83, seasonId: 23621),
      same(historical),
    );
    expect(repository.cachedRosters.value, {
      const TeamContractQuery(teamId: 83, seasonId: 23621): historical,
    });
  });

  test('supports a trailing base-URI slash and an empty player list', () async {
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/teams/83/contracts');
            return http.Response(
              jsonEncode(_rosterJson(players: const [])),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    final roster = await repository.loadForTeam(83);

    expect(roster.players, isEmpty);
    expect(repository.cachedForTeam(83), same(roster));
  });

  test('keeps different teams in separate cache entries', () async {
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient((request) async {
            final teamId = int.parse(request.url.pathSegments[2]);
            return http.Response(jsonEncode(_rosterJson(teamId: teamId)), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(19);

    expect(first.teamId, 83);
    expect(second.teamId, 19);
    expect(repository.cachedRosters.value, hasLength(2));
  });

  test('surfaces unavailable, authentication, and server failures', () async {
    final responses = [
      http.Response('Not found', 404),
      http.Response('Unauthorized', 401),
      http.Response('Server error', 500),
    ];
    var requestCount = 0;
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(
        repository.loadForTeam(83),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(repository.cachedRosters.value, isEmpty);
  });

  test('rejects malformed and mismatched responses without caching', () async {
    final responses = [
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_rosterJson(teamId: 19)), 200),
      http.Response(
        jsonEncode({..._rosterJson(), 'season_id': '25659'}),
        200,
      ),
    ];
    var requestCount = 0;
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(repository.loadForTeam(83), throwsFormatException);
    }
    expect(repository.cachedRosters.value, isEmpty);
  });

  test('rejects a mismatched requested season without caching', () async {
    final repository = ApiTeamContractRepository(
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(_rosterJson(seasonId: 25659)),
              200,
            ),
          ),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForTeam(83, seasonId: 23621),
      throwsFormatException,
    );
    expect(repository.cachedRosters.value, isEmpty);
  });
}

Map<String, dynamic> _rosterJson({
  int teamId = 83,
  int seasonId = 25659,
  bool isCurrent = true,
  List<Map<String, dynamic>>? players,
}) {
  return {
    'team_id': teamId,
    'season_id': seasonId,
    'is_current': isCurrent,
    'players': players ??
        [
          {
            'player_id': 1001,
            'player_name': 'Contract Player',
            'player_image': null,
            'position_group_id': 27,
            'jersey_number': null,
            'date_of_birth': '1998-05-12',
            'estimated_weekly_gross_eur': 125000,
            'leadership_role': 'captain',
            'start_date': '2025-07-01',
            'end_date': '2028-06-30',
          },
        ],
  };
}
