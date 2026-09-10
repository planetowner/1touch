import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_repository.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  test('requests, maps, and caches a verified team-match page', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/teams/8/matches');
      expect(request.url.queryParameters, {
        'status': 'upcoming',
        'start': '2026-08-01',
        'end': '2026-08-31',
        'limit': '20',
        'offset': '40',
      });
      expect(request.headers['X-User-Id'], '1');
      expect(request.headers['Accept'], 'application/json');
      return http.Response(
        jsonEncode({
          'items': [_fixtureJson()],
          'limit': 20,
          'offset': 40,
        }),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      client: client,
      apiBaseUri: Uri.parse('http://localhost:8000/v1'),
      requestHeaders: const {'X-User-Id': '1'},
    );

    final loaded = await repository.loadForTeam(
      8,
      status: FixtureStatus.upcoming,
      start: DateTime(2026, 8),
      end: DateTime(2026, 8, 31, 23, 59),
      limit: 20,
      offset: 40,
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.fixtureId, 19712345);
    expect(loaded.single.status, FixtureStatus.upcoming);
    expect(repository.allFixtures, hasLength(1));
    expect(repository.findById(19712345), same(loaded.single));
    expect(repository.fixtures.value, same(repository.allFixtures));
    expect(() => loaded.clear(), throwsUnsupportedError);
  });

  test('merges pages into an immutable chronological cache by fixture ID',
      () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      final fixture = requestCount == 1
          ? _fixtureJson(
              fixtureId: 2,
              startingAt: '2026-09-02 15:00:00',
            )
          : _fixtureJson(
              fixtureId: 1,
              startingAt: '2026-09-01 15:00:00',
            );
      return http.Response(
        jsonEncode({
          'items': [fixture],
          'limit': 1,
          'offset': requestCount - 1,
        }),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      client: client,
      apiBaseUri: Uri.parse('http://localhost:8000/v1/'),
      requestHeaders: const {'X-User-Id': '1'},
    );

    await repository.loadForTeam(8, limit: 1);
    await repository.loadForTeam(8, limit: 1, offset: 1);

    expect(
      repository.allFixtures.map((fixture) => fixture.fixtureId),
      [1, 2],
    );
    expect(() => repository.allFixtures.clear(), throwsUnsupportedError);
  });

  test('omits optional filters and sends backend pagination defaults',
      () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters, {
        'limit': '50',
        'offset': '0',
      });
      return http.Response(
        jsonEncode({'items': [], 'limit': 50, 'offset': 0}),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      client: client,
      apiBaseUri: Uri.parse('http://localhost:8000/v1/'),
      requestHeaders: const {'X-User-Id': '1'},
    );

    expect(await repository.loadForTeam(8), isEmpty);
  });

  test('rejects HTTP failures and malformed response roots', () async {
    final responses = [
      http.Response('Unavailable', 503),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiFixtureRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('http://localhost:8000/v1/'),
      requestHeaders: const {'X-User-Id': '1'},
    );

    await expectLater(
      repository.loadForTeam(8),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.loadForTeam(8),
      throwsFormatException,
    );
    expect(repository.allFixtures, isEmpty);
  });

  test('rejects invalid queries before sending a request', () async {
    var requestCount = 0;
    final repository = ApiFixtureRepository(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('http://localhost:8000/v1/'),
      requestHeaders: const {'X-User-Id': '1'},
    );

    await expectLater(
      repository.loadForTeam(8, status: FixtureStatus.unknown),
      throwsArgumentError,
    );
    await expectLater(
      repository.loadForTeam(8, limit: 201),
      throwsRangeError,
    );
    await expectLater(
      repository.loadForTeam(8, offset: -1),
      throwsRangeError,
    );
    expect(requestCount, 0);
  });
}

Map<String, dynamic> _fixtureJson({
  int fixtureId = 19712345,
  String startingAt = '2026-08-29 14:00:00',
}) {
  return {
    'fixture_id': fixtureId,
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
    'starting_at': startingAt,
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': null,
    'away_score': null,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/liverpool.png',
    'away_team_logo': null,
  };
}
