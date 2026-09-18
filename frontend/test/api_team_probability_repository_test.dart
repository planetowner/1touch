import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';

void main() {
  test('requests, maps, and caches current team probability cards', () async {
    var requestCount = 0;
    final repository = ApiTeamProbabilityRepository(
      client: MockClient((request) async {
        requestCount++;
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/teams/83/probability');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_probabilityJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(second, same(first));
    expect(requestCount, 1);
    expect(first.teamId, 83);
    expect(first.teamName, 'FC Barcelona');
    expect(first.competitionId, 564);
    expect(first.seasonId, 27965);
    expect(first.seasonName, '2026/2027');
    expect(first.asOf, DateTime.utc(2026, 9, 18));
    expect(first.comparison.available, isTrue);
    expect(first.comparison.asOf, DateTime.utc(2026, 9, 11));
    expect(first.cards, hasLength(2));
    expect(first.cards.first.event, 'league_winner');
    expect(first.cards.first.probability, 0.324);
    expect(first.cards.first.changePercentagePoints, 2.4);
    expect(first.cards.last.changePercentagePoints, isNull);
    expect(first.pendingOutcomes, ['ucl_qualification', 'cup_outcomes']);
    expect(repository.cachedForTeam(83), same(first));
    expect(repository.cachedForTeam(83, seasonId: 27965), same(first));
    expect(() => first.cards.clear(), throwsUnsupportedError);
    expect(() => first.pendingOutcomes.clear(), throwsUnsupportedError);
    expect(
      () => repository.cachedSnapshots.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('requests and verifies an explicit season', () async {
    final repository = ApiTeamProbabilityRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/teams/83/probability');
        expect(request.url.queryParameters, {'season_id': '27965'});
        return http.Response(jsonEncode(_probabilityJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    final result = await repository.loadForTeam(83, seasonId: 27965);

    expect(result.seasonId, 27965);
    expect(repository.cachedForTeam(83, seasonId: 27965), same(result));
  });

  test('preserves an unavailable comparison instead of inventing zero',
      () async {
    final repository = ApiTeamProbabilityRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(
            _probabilityJson(
              comparisonAvailable: false,
              comparisonAsOf: null,
              firstChangePp: null,
            ),
          ),
          200,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    final result = await repository.loadForTeam(83);

    expect(result.comparison.available, isFalse);
    expect(result.comparison.asOf, isNull);
    expect(result.cards.every((card) => card.changePercentagePoints == null),
        isTrue);
  });

  test('maps not found to an unavailable team feature', () async {
    final repository = ApiTeamProbabilityRepository(
      client: MockClient((_) async => http.Response('Not found', 404)),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<TeamFeatureUnavailableException>()),
    );
    expect(repository.cachedSnapshots.value, isEmpty);
  });

  test('surfaces authentication and server failures', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response('Server error', 500),
    ];
    var requestCount = 0;
    final repository = ApiTeamProbabilityRepository(
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
    expect(repository.cachedSnapshots.value, isEmpty);
  });

  test('rejects malformed or mismatched responses without caching', () async {
    final malformedCard = _probabilityJson();
    (malformedCard['cards'] as List<Map<String, dynamic>>)
        .first['probability'] = 1.1;
    final missingNullable = _probabilityJson();
    (missingNullable['cards'] as List<Map<String, dynamic>>)
        .first
        .remove('change_pp');
    final responses = [
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_probabilityJson(teamId: 19)), 200),
      http.Response(jsonEncode(_probabilityJson(seasonId: 1)), 200),
      http.Response(jsonEncode(malformedCard), 200),
      http.Response(jsonEncode(missingNullable), 200),
      http.Response(
        jsonEncode({..._probabilityJson(), 'as_of': 'not-a-date'}),
        200,
      ),
    ];
    var requestCount = 0;
    final repository = ApiTeamProbabilityRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.loadForTeam(83), throwsFormatException);
    await expectLater(repository.loadForTeam(83), throwsFormatException);
    await expectLater(
      repository.loadForTeam(83, seasonId: 27965),
      throwsFormatException,
    );
    for (var i = 0; i < 3; i++) {
      await expectLater(repository.loadForTeam(83), throwsFormatException);
    }
    expect(repository.cachedSnapshots.value, isEmpty);
  });
}

Map<String, dynamic> _probabilityJson({
  int teamId = 83,
  int seasonId = 27965,
  bool comparisonAvailable = true,
  String? comparisonAsOf = '2026-09-11T00:00:00Z',
  double? firstChangePp = 2.4,
}) {
  return {
    'team_id': teamId,
    'team_name': 'FC Barcelona',
    'competition_id': 564,
    'season_id': seasonId,
    'season_name': '2026/2027',
    'as_of': '2026-09-18T00:00:00Z',
    'comparison': {
      'basis': 'previous_league_fixture_utc_day_start',
      'available': comparisonAvailable,
      'as_of': comparisonAsOf,
    },
    'cards': <Map<String, dynamic>>[
      {
        'event': 'league_winner',
        'competition_id': 564,
        'category': 'TITLE',
        'probability': 0.324,
        'change_pp': firstChangePp,
        'entropy': 0.909,
      },
      {
        'event': 'top_4',
        'competition_id': 564,
        'category': 'LEAGUE_FINISH',
        'probability': 0.781,
        'change_pp': null,
        'entropy': null,
      },
    ],
    'pending_outcomes': ['ucl_qualification', 'cup_outcomes'],
  };
}
