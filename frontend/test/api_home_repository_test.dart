import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/home/api/api_home_repository.dart';

void main() {
  test('requests and maps Home with a UTC calendar boundary envelope',
      () async {
    final repository = ApiHomeRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/home');
        expect(request.url.queryParameters, {
          'start': '2026-08-31',
          'end': '2026-10-01',
        });
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_homeJson()), 200);
      }),
      apiBaseUri: Uri.parse('http://localhost:8000/v1'),
      requestHeaders: const {
        'Authorization': 'Bearer session-token',
      },
    );

    final home = await repository.load(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );

    expect(home.favoriteTeam.teamId, 8);
    expect(home.followingTeams.map((team) => team.teamId), [8, 19]);
    expect(home.calendar.single.fixture.fixtureId, 1003);
    expect(home.calendar.single.fixture.kickoff, DateTime.utc(2026, 9, 1));
    expect(home.calendar.single.opponent.name, 'Arsenal');
  });

  test('omits date parameters and supports a trailing base-URI slash',
      () async {
    final repository = ApiHomeRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/home');
        expect(request.url.queryParameters, isEmpty);
        return http.Response(jsonEncode(_homeJson(calendar: const [])), 200);
      }),
      apiBaseUri: Uri.parse('http://localhost:8000/v1/'),
      requestHeaders: const {},
    );

    final home = await repository.load();

    expect(home.calendar, isEmpty);
  });

  test('pads whichever optional date boundary is supplied', () async {
    var requestCount = 0;
    final repository = ApiHomeRepository(
      client: MockClient((request) async {
        requestCount++;
        expect(
          request.url.queryParameters,
          requestCount == 1 ? {'start': '2026-08-31'} : {'end': '2026-10-01'},
        );
        return http.Response(jsonEncode(_homeJson(calendar: const [])), 200);
      }),
      apiBaseUri: Uri.parse('http://localhost:8000/v1'),
      requestHeaders: const {},
    );

    await repository.load(start: DateTime(2026, 9, 1));
    await repository.load(end: DateTime(2026, 9, 30));

    expect(requestCount, 2);
  });

  test('surfaces HTTP failures and malformed response roots', () async {
    final responses = [
      http.Response('Unavailable', 503),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiHomeRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('http://localhost:8000/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.load(), throwsA(isA<http.ClientException>()));
    await expectLater(repository.load(), throwsFormatException);
  });
}

Map<String, dynamic> _homeJson({List<Map<String, dynamic>>? calendar}) {
  return {
    'favorite_team': _teamJson(8, 'Liverpool', 'LIV'),
    'following_teams': [
      _teamJson(8, 'Liverpool', 'LIV'),
      _teamJson(19, 'Arsenal', 'ARS'),
    ],
    'next_match': null,
    'last_match': null,
    'calendar': calendar ?? [_fixtureJson()],
  };
}

Map<String, dynamic> _teamJson(int id, String name, String shortCode) {
  return {
    'team_id': id,
    'name': name,
    'short_code': shortCode,
    'image_path': 'https://cdn.example/$id.png',
  };
}

Map<String, dynamic> _fixtureJson() {
  return {
    'fixture_id': 1003,
    'competition_id': 8,
    'season_id': 25583,
    'competition_type': 'league',
    'round_name': '3',
    'stage_id': 77432101,
    'stage_name': 'Regular Season',
    'round_id': 375001,
    'group_id': null,
    'aggregate_id': null,
    'leg': '1/1',
    'venue_id': 206,
    'state_id': 1,
    'state_code': 'NS',
    'state_name': 'Not Started',
    'status': 'upcoming',
    'starting_at': '2026-09-01 00:00:00',
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': null,
    'away_score': null,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/8.png',
    'away_team_logo': 'https://cdn.example/19.png',
  };
}
