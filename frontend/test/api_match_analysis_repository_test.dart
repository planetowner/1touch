import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/match_analysis/api/api_match_analysis_repository.dart';

void main() {
  test('loads and independently caches analysis and shot-map responses',
      () async {
    var requests = 0;
    final repository = ApiMatchAnalysisRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requests++;
            expect(request.method, 'GET');
            expect(request.headers['Authorization'], 'Bearer test-session');
            expect(request.headers['Accept'], 'application/json');
            if (request.url.path.endsWith('/analysis')) {
              return http.Response(jsonEncode(_analysisJson()), 200);
            }
            expect(request.url.path, '/v1/fixtures/42/shotmap');
            return http.Response(jsonEncode(_shotMapJson()), 200);
          }),
          baseUri: Uri.parse('https://example.test/v1'),
          requestHeaders: () => const {'Authorization': 'Bearer test-session'}),
    );

    final analysis = await repository.loadAnalysis(42);
    final shotMap = await repository.loadShotMap(42);

    expect(analysis.home?.attack.keyPasses, 3);
    expect(analysis.away?.progression.progressivePasses, 0);
    expect(analysis.away?.progression.channels.first.percentage, isNull);
    expect(analysis.away?.defensiveActivity.recoveries, isNull);
    expect(analysis.away?.defensiveActivity.actions, hasLength(1));
    expect(shotMap.homeCount, 1);
    expect(shotMap.shots.single.playerName, isNull);
    expect(shotMap.shots.single.start.x, 84.5);
    expect(repository.cachedAnalysisForFixture(42), same(analysis));
    expect(repository.cachedShotMapForFixture(42), same(shotMap));

    expect(await repository.loadAnalysis(42), same(analysis));
    expect(await repository.loadShotMap(42), same(shotMap));
    expect(requests, 2);
  });

  test('preserves the unavailable response instead of creating fake data',
      () async {
    final repository = ApiMatchAnalysisRepository(
      api: ApiClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/analysis')) {
              return http.Response(
                jsonEncode(
                    {'fixture_id': 42, 'available': false, 'teams': null}),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'fixture_id': 42,
                'available': false,
                'counts': null,
                'shots': [],
              }),
              200,
            );
          }),
          baseUri: Uri.parse('https://example.test/v1/'),
          requestHeaders: () => const {}),
    );

    expect((await repository.loadAnalysis(42)).available, isFalse);
    expect((await repository.loadShotMap(42)).available, isFalse);
  });

  test('rejects failed requests and mismatched fixture identities', () async {
    var request = 0;
    final repository = ApiMatchAnalysisRepository(
      api: ApiClient(
          client: MockClient((_) async {
            request++;
            return request == 1
                ? http.Response('Unavailable', 503)
                : http.Response(
                    jsonEncode({..._analysisJson(), 'fixture_id': 99}),
                    200,
                  );
          }),
          baseUri: Uri.parse('https://example.test/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadShotMap(42),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(repository.loadAnalysis(42), throwsFormatException);
  });
}

Map<String, Object?> _analysisJson() => {
      'fixture_id': 42,
      'available': true,
      'teams': {
        'home': _teamJson(teamId: 10, complete: true),
        'away': _teamJson(teamId: 20, complete: false),
      },
    };

Map<String, Object?> _teamJson({
  required int teamId,
  required bool complete,
}) =>
    {
      'team_id': teamId,
      'attack': {
        'key_passes': teamId == 10 ? 3 : 1,
        'completed_passes_into_final_third': teamId == 10 ? 24 : 8,
      },
      'progression': {
        'completed_passes': teamId == 10 ? 412 : 199,
        'progressive_passes': teamId == 10 ? 30 : 0,
        'channels': [
          {
            'channel': 'left',
            'count': teamId == 10 ? 10 : 0,
            'percentage': teamId == 10 ? 33.33 : null,
          },
          {
            'channel': 'center',
            'count': teamId == 10 ? 12 : 0,
            'percentage': teamId == 10 ? 40.0 : null,
          },
          {
            'channel': 'right',
            'count': teamId == 10 ? 8 : 0,
            'percentage': teamId == 10 ? 26.67 : null,
          },
        ],
      },
      'defensive_activity': {
        'complete': complete,
        'missing_position_count': complete ? 0 : 2,
        'action_count': 1,
        'actions': [
          {
            'attacking_position': {'x': 62.5, 'y': 40.0},
          },
        ],
        'recoveries': complete ? 18 : null,
        'high_regains': complete ? 4 : null,
        'halves': [
          {
            'half': 'own',
            'percentage': complete ? 66.67 : null,
          },
          {
            'half': 'opponent',
            'percentage': complete ? 33.33 : null,
          },
        ],
        'average_regain_x': complete ? 40.0 : null,
        'average_regain_height_m': complete ? 42.2 : null,
      },
    };

Map<String, Object?> _shotMapJson() => {
      'fixture_id': 42,
      'available': true,
      'counts': {'home': 1, 'away': 0},
      'shots': [
        {
          'external_event_id': 'shot-1',
          'team_id': 10,
          'player_id': null,
          'player_name': null,
          'minute': 12,
          'extra_minute': null,
          'result': 'goal',
          'start': {'x': 84.5, 'y': 51.0},
          'end': {'x': 100.0, 'y': 49.0},
        },
      ],
    };
