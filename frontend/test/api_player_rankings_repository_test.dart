import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/players/api/api_player_rankings_repository.dart';
import 'package:onetouch/models/player_rankings.dart';

void main() {
  test('requests and maps one rankings page', () async {
    final repository = ApiPlayerRankingsRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/players/rankings');
        expect(request.url.queryParameters, {
          'season_id': '28083',
          'limit': '20',
          'offset': '0',
        });
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_rankingsJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final page = await repository.load(seasonId: 28083);

    expect(page.competitionId, 8);
    expect(page.seasonName, '2026/2027');
    expect(page.method, PlayerRankingMethod.fixedHistoricalPercentile);
    expect(page.reference.frozenAt, DateTime.utc(2026, 9, 1, 12));
    expect(page.items.single.playerImage, isNull);
    expect(page.items.single.updatedAt, DateTime.utc(2026, 9, 18, 20));
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('validates request arguments before sending HTTP', () async {
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.load(seasonId: 0), throwsRangeError);
    await expectLater(
      repository.load(seasonId: 1, limit: 101),
      throwsRangeError,
    );
    await expectLater(
      repository.load(seasonId: 1, offset: -1),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects HTTP, malformed, and mismatched responses', () async {
    final mismatched = _rankingsJson()..['season_id'] = 999;
    final invalidMethod = _rankingsJson()..['method'] = 'live_percentile';
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(mismatched), 200),
      http.Response(jsonEncode(invalidMethod), 200),
    ];
    var index = 0;
    final repository = ApiPlayerRankingsRepository(
      client: MockClient((_) async => responses[index++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.load(seasonId: 28083),
      throwsA(isA<http.ClientException>()),
    );
    for (var i = 1; i < responses.length; i++) {
      await expectLater(
        repository.load(seasonId: 28083),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _rankingsJson() => {
      'competition_id': 8,
      'season_id': 28083,
      'season_name': '2026/2027',
      'method': 'fixed_historical_percentile',
      'reference': {
        'start_season_name': '2020/2021',
        'end_season_name': '2024/2025',
        'minimum_rated_matches': 10,
        'sample_count': 900,
        'frozen_at': '2026-09-01T12:00:00Z',
      },
      'total': 1,
      'limit': 20,
      'offset': 0,
      'items': [
        {
          'rank': 1,
          'player_id': 101,
          'player_name': 'Player One',
          'player_image': null,
          'rated_matches': 12,
          'average_rating': 7.25,
          'percentile_score': 98.37,
          'display_score': 9.8,
          'updated_at': '2026-09-18T20:00:00+00:00',
        },
      ],
    };
