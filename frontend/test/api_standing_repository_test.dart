import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/standings/api/api_standing_repository.dart';

void main() {
  test('requests, maps, and caches an explicit competition season', () async {
    var requestCount = 0;
    final repository = ApiStandingRepository(
      client: MockClient((request) async {
        requestCount++;
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/competitions/8/standings');
        expect(request.url.queryParameters, {'season_id': '25583'});
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_responseJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final first = await repository.loadForCompetition(8, seasonId: 25583);
    final second = await repository.loadForCompetition(8, seasonId: 25583);

    expect(first.single.teamName, 'Manchester City');
    expect(second, same(first));
    expect(
      repository.cachedForCompetition(8, seasonId: 25583),
      same(first),
    );
    expect(repository.forCompetition(8, seasonId: 25583), first);
    expect(repository.findForTeam(8, 9, seasonId: 25583), same(first.single));
    expect(requestCount, 1);
  });

  test('omits season_id and caches the backend-resolved current season',
      () async {
    final repository = ApiStandingRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters, isEmpty);
        return http.Response(jsonEncode(_responseJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    final current = await repository.loadForCompetition(8);

    expect(repository.cachedForCompetition(8), same(current));
    expect(
      repository.cachedForCompetition(8, seasonId: 25583),
      same(current),
    );
    expect(repository.forCompetition(8), current);
  });

  test('separates competition and season cache entries', () async {
    final repository = ApiStandingRepository(
      client: MockClient((request) async {
        final competitionId = int.parse(request.url.pathSegments[2]);
        final seasonId = int.parse(request.url.queryParameters['season_id']!);
        return http.Response(
          jsonEncode(_responseJson(
            competitionId: competitionId,
            seasonId: seasonId,
          )),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await repository.loadForCompetition(8, seasonId: 25583);
    await repository.loadForCompetition(8, seasonId: 23614);
    await repository.loadForCompetition(564, seasonId: 25659);

    expect(repository.cachedTables.value, hasLength(3));
    expect(repository.allStandings, hasLength(3));
  });

  test('rejects HTTP, malformed, and mismatched responses without caching',
      () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_responseJson(competitionId: 564)), 200),
      http.Response(jsonEncode(_responseJson(seasonId: 23614)), 200),
    ];
    var index = 0;
    final repository = ApiStandingRepository(
      client: MockClient((_) async => responses[index++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.loadForCompetition(8, seasonId: 25583),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.loadForCompetition(8, seasonId: 25583),
      throwsFormatException,
    );
    await expectLater(
      repository.loadForCompetition(8, seasonId: 25583),
      throwsFormatException,
    );
    await expectLater(
      repository.loadForCompetition(8, seasonId: 25583),
      throwsFormatException,
    );
    expect(repository.cachedTables.value, isEmpty);
  });
}

Map<String, dynamic> _responseJson({
  int competitionId = 8,
  int seasonId = 25583,
}) =>
    {
      'competition_id': competitionId,
      'season_id': seasonId,
      'rows': [
        {
          'position': 1,
          'rank_delta': null,
          'team_id': 9,
          'team_name': 'Manchester City',
          'team_logo': null,
          'matches_played': 3,
          'won': 2,
          'draw': 1,
          'lost': 0,
          'goals_for': 8,
          'goals_against': 2,
          'goal_diff': 6,
          'points': 7,
          'last5_form': ['W', 'D'],
        },
      ],
    };
