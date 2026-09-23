import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_repository.dart';

void main() {
  test('requests, maps, and caches the default Best Eleven', () async {
    var requestCount = 0;
    final repository = ApiBestElevenRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestCount++;
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/teams/83/best-eleven');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_bestElevenJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(first, same(second));
    expect(first?.teamId, 83);
    expect(first?.seasonId, 25659);
    expect(first?.formation, '4-3-3');
    expect(first?.players.single.playerName, isNull);
    expect(repository.cachedForTeam(83), same(first));
    expect(requestCount, 1);
    expect(
      () => repository.cachedLineups.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('sends the requested season and normalized formation', () async {
    final repository = ApiBestElevenRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/teams/83/best-eleven');
            expect(request.url.queryParameters, {
              'season_id': '23621',
              'formation': '4-2-3-1',
            });
            return http.Response(
              jsonEncode(_bestElevenJson(
                seasonId: 23621,
                formation: '4-2-3-1',
              )),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    final result = await repository.loadForTeam(
      83,
      seasonId: 23621,
      formation: ' 4-2-3-1 ',
    );

    expect(result?.seasonId, 23621);
    expect(result?.formation, '4-2-3-1');
    expect(
      repository.cachedForTeam(
        83,
        seasonId: 23621,
        formation: '4-2-3-1',
      ),
      same(result),
    );
  });

  test('returns null for unavailable Best Eleven data without caching it',
      () async {
    var requestCount = 0;
    final repository = ApiBestElevenRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requestCount++;
            return http.Response(
              jsonEncode({'detail': 'Best eleven not available'}),
              404,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    expect(await repository.loadForTeam(83), isNull);
    expect(await repository.loadForTeam(83), isNull);
    expect(repository.cachedLineups.value, isEmpty);
    expect(requestCount, 2);
  });

  test('surfaces authentication and other HTTP failures', () async {
    final responses = [
      http.Response(jsonEncode({'detail': 'Bearer session required'}), 401),
      http.Response('Server error', 500),
    ];
    var requestCount = 0;
    final repository = ApiBestElevenRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('rejects a malformed response root', () async {
    final repository = ApiBestElevenRepository(
      api: ApiClient(
          client: MockClient((_) async => http.Response(jsonEncode([]), 200)),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(repository.loadForTeam(83), throwsFormatException);
  });

  test('rejects responses for another team, season, or formation', () async {
    final responses = [
      _bestElevenJson(teamId: 19),
      _bestElevenJson(seasonId: 25659),
      _bestElevenJson(formation: '4-3-3'),
    ];
    var requestCount = 0;
    final repository = ApiBestElevenRepository(
      api: ApiClient(
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode(responses[requestCount++]), 200),
          ),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(repository.loadForTeam(83), throwsFormatException);
    await expectLater(
      repository.loadForTeam(83, seasonId: 23621),
      throwsFormatException,
    );
    await expectLater(
      repository.loadForTeam(83, formation: '4-2-3-1'),
      throwsFormatException,
    );
    expect(repository.cachedLineups.value, isEmpty);
  });
}

Map<String, dynamic> _bestElevenJson({
  int teamId = 83,
  int seasonId = 25659,
  String formation = '4-3-3',
}) {
  return {
    'team_id': teamId,
    'season_id': seasonId,
    'formation': formation,
    'matches_used': 20,
    'total_valid_matches': 30,
    'usage_percentage': 66.7,
    'formations': [
      {
        'formation': formation,
        'matches_used': 20,
        'total_valid_matches': 30,
        'usage_percentage': 66.7,
        'is_default': true,
      },
    ],
    'players': [
      {
        'slot_key': '1:1',
        'slot_index': 0,
        'player_id': 1,
        'player_name': null,
        'player_image': null,
        'position_group_code': 'GK',
        'position_code': 'GK',
        'starts': 20,
      },
    ],
  };
}
