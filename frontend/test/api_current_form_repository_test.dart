import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/current_form/api/api_current_form_repository.dart';

void main() {
  group('loadOptions', () {
    test('requests, maps, and caches the global option list', () async {
      var requestCount = 0;
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((request) async {
              requestCount++;
              expect(request.method, 'GET');
              expect(request.url.path, '/v1/teams/83/current-form/options');
              expect(request.url.queryParameters, {'limit': '200'});
              expect(request.headers['Accept'], 'application/json');
              expect(request.headers['Authorization'], 'Bearer session-token');
              return http.Response(
                jsonEncode({
                  'items': [_optionJson()],
                  'limit': 200,
                }),
                200,
              );
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () =>
                const {'Authorization': 'Bearer session-token'}),
      );

      final first = await repository.loadOptions(83);
      final second = await repository.loadOptions(83);

      expect(second, same(first));
      expect(first.single.leagueId, 564);
      expect(repository.cachedOptionsFor(83), same(first));
      expect(requestCount, 1);
    });

    test('normalizes search and keeps each limit in a separate cache key',
        () async {
      final requests = <Uri>[];
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((request) async {
              requests.add(request.url);
              final limit = int.parse(request.url.queryParameters['limit']!);
              return http.Response(
                  jsonEncode({'items': [], 'limit': limit}), 200);
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1/'),
            requestHeaders: () => const {}),
      );

      final first = await repository.loadOptions(
        83,
        search: ' BARCELONA ',
        limit: 10,
      );
      final repeated = await repository.loadOptions(
        83,
        search: 'barcelona',
        limit: 10,
      );
      await repository.loadOptions(83, limit: 1);

      expect(repeated, same(first));
      expect(requests, hasLength(2));
      expect(requests.first.queryParameters, {
        'search': 'barcelona',
        'limit': '10',
      });
      expect(repository.cachedOptions.value, hasLength(2));
    });

    test('validates limits before sending a request', () async {
      var requested = false;
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((_) async {
              requested = true;
              return http.Response('{}', 200);
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      await expectLater(repository.loadOptions(83, limit: 0), throwsRangeError);
      await expectLater(
        repository.loadOptions(83, limit: 1001),
        throwsRangeError,
      );
      expect(requested, isFalse);
    });

    test('rejects HTTP failures, malformed roots, and mismatched limits',
        () async {
      final responses = [
        http.Response('Unauthorized', 401),
        http.Response(jsonEncode([]), 200),
        http.Response(jsonEncode({'items': [], 'limit': 10}), 200),
      ];
      var requestCount = 0;
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((_) async => responses[requestCount++]),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      await expectLater(
        repository.loadOptions(83),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(repository.loadOptions(83), throwsFormatException);
      await expectLater(repository.loadOptions(83), throwsFormatException);
      expect(repository.cachedOptions.value, isEmpty);
    });
  });

  group('loadComparison', () {
    test('requests, maps, and caches an exact comparison', () async {
      var requestCount = 0;
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((request) async {
              requestCount++;
              expect(request.url.path, '/v1/teams/83/current-form');
              expect(request.url.queryParameters, {
                'compare_team_id': '3468',
                'compare_season_id': '23621',
                'season_id': '25659',
              });
              expect(request.headers['Authorization'], 'Bearer session-token');
              return http.Response(jsonEncode(_comparisonJson()), 200);
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () =>
                const {'Authorization': 'Bearer session-token'}),
      );

      final first = await repository.loadComparison(
        83,
        seasonId: 25659,
        compareTeamId: 3468,
        compareSeasonId: 23621,
      );
      final second = await repository.loadComparison(
        83,
        seasonId: 25659,
        compareTeamId: 3468,
        compareSeasonId: 23621,
      );

      expect(second, same(first));
      expect(first?.current.teamId, 83);
      expect(first?.comparison.teamId, 3468);
      expect(requestCount, 1);
      expect(
        repository.cachedComparisonFor(
          83,
          seasonId: 25659,
          compareTeamId: 3468,
          compareSeasonId: 23621,
        ),
        same(first),
      );
    });

    test('omits the optional current season', () async {
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((request) async {
              expect(request.url.queryParameters, {
                'compare_team_id': '3468',
                'compare_season_id': '23621',
              });
              return http.Response(jsonEncode(_comparisonJson()), 200);
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1/'),
            requestHeaders: () => const {}),
      );

      expect(
        await repository.loadComparison(
          83,
          compareTeamId: 3468,
          compareSeasonId: 23621,
        ),
        isNotNull,
      );
    });

    test('surfaces unavailable comparison data as an HTTP failure', () async {
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((_) async {
              return http.Response(
                jsonEncode({'detail': 'Comparison team-season not available'}),
                404,
              );
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      await expectLater(
        repository.loadComparison(
          83,
          compareTeamId: 3468,
          compareSeasonId: 23621,
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(repository.cachedComparisons.value, isEmpty);
    });

    test('rejects HTTP failures and malformed response roots', () async {
      final responses = [
        http.Response('Unauthorized', 401),
        http.Response(jsonEncode([]), 200),
      ];
      var requestCount = 0;
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient((_) async => responses[requestCount++]),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      await expectLater(
        repository.loadComparison(
          83,
          compareTeamId: 3468,
          compareSeasonId: 23621,
        ),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(
        repository.loadComparison(
          83,
          compareTeamId: 3468,
          compareSeasonId: 23621,
        ),
        throwsFormatException,
      );
    });

    test('rejects mismatched current and comparison identities', () async {
      final responses = [
        _comparisonJson(currentTeamId: 19),
        _comparisonJson(currentSeasonId: 27965),
        _comparisonJson(comparisonTeamId: 19),
        _comparisonJson(comparisonSeasonId: 21646),
      ];
      var requestCount = 0;
      final repository = ApiCurrentFormRepository(
        api: ApiClient(
            client: MockClient(
              (_) async =>
                  http.Response(jsonEncode(responses[requestCount++]), 200),
            ),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      for (var i = 0; i < responses.length; i++) {
        await expectLater(
          repository.loadComparison(
            83,
            seasonId: 25659,
            compareTeamId: 3468,
            compareSeasonId: 23621,
          ),
          throwsFormatException,
        );
      }
      expect(repository.cachedComparisons.value, isEmpty);
    });
  });
}

Map<String, dynamic> _optionJson() => {
      'team_id': 83,
      'team_name': 'FC Barcelona',
      'team_short_code': 'BAR',
      'team_logo': null,
      'competition_id': 564,
      'season_id': 25659,
      'season_name': '2025/2026',
      'rounds_available': 2,
      'latest_round': 2,
    };

Map<String, dynamic> _comparisonJson({
  int currentTeamId = 83,
  int currentSeasonId = 25659,
  int comparisonTeamId = 3468,
  int comparisonSeasonId = 23621,
}) =>
    {
      'current': _seriesJson(
        teamId: currentTeamId,
        seasonId: currentSeasonId,
        seasonName: '2025/2026',
        isCurrent: true,
      ),
      'comparison': _seriesJson(
        teamId: comparisonTeamId,
        seasonId: comparisonSeasonId,
        seasonName: '2024/2025',
        isCurrent: false,
      ),
      'max_round': 2,
      'max_points': 4,
    };

Map<String, dynamic> _seriesJson({
  required int teamId,
  required int seasonId,
  required String seasonName,
  required bool isCurrent,
}) =>
    {
      'team_id': teamId,
      'team_name': 'Team $teamId',
      'team_short_code': 'T$teamId',
      'team_logo': null,
      'competition_id': 564,
      'season_id': seasonId,
      'season_name': seasonName,
      'is_current': isCurrent,
      'points': [
        {
          'round_no': 0,
          'match_date': null,
          'cumulative_points': 0,
        },
        {
          'round_no': 2,
          'match_date': '2025-08-16T19:00:00',
          'cumulative_points': 4,
        },
      ],
    };
