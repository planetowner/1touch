import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_repository.dart';

void main() {
  test('requests, maps, and caches a Team overview', () async {
    var requestCount = 0;
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestCount++;
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/teams/83');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_overviewJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(first.name, 'FC Barcelona');
    expect(second, same(first));
    expect(repository.cachedForTeam(83), same(first));
    expect(requestCount, 1);
    expect(() => repository.cachedTeams.value.clear(), throwsUnsupportedError);
  });

  test('supports a trailing base URI and separate team cache entries',
      () async {
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
          client: MockClient((request) async {
            final teamId = int.parse(request.url.pathSegments.last);
            return http.Response(
              jsonEncode(_overviewJson(teamId: teamId)),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    await repository.loadForTeam(83);
    await repository.loadForTeam(19);

    expect(repository.cachedTeams.value.keys, {83, 19});
  });

  test('deduplicates simultaneous requests for the same team', () async {
    var requestCount = 0;
    final response = Completer<http.Response>();
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
          client: MockClient((_) {
            requestCount++;
            return response.future;
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final firstLoad = repository.loadForTeam(83);
    final secondLoad = repository.loadForTeam(83);

    await Future<void>.delayed(Duration.zero);
    expect(requestCount, 1);
    response.complete(http.Response(jsonEncode(_overviewJson()), 200));
    final results = await Future.wait([firstLoad, secondLoad]);

    expect(results[1], same(results[0]));
    expect(requestCount, 1);
  });

  test('does not deduplicate requests for different teams', () async {
    var requestCount = 0;
    final responses = <int, Completer<http.Response>>{};
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
          client: MockClient((request) {
            requestCount++;
            final teamId = int.parse(request.url.pathSegments.last);
            return responses
                .putIfAbsent(teamId, () => Completer<http.Response>())
                .future;
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final firstLoad = repository.loadForTeam(83);
    final secondLoad = repository.loadForTeam(19);

    await Future<void>.delayed(Duration.zero);
    expect(requestCount, 2);
    responses[83]!.complete(
      http.Response(jsonEncode(_overviewJson()), 200),
    );
    responses[19]!.complete(
      http.Response(jsonEncode(_overviewJson(teamId: 19)), 200),
    );
    await Future.wait([firstLoad, secondLoad]);

    expect(requestCount, 2);
  });

  test('rejects HTTP failures, malformed roots, and mismatched teams',
      () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_overviewJson(teamId: 19)), 200),
    ];
    var index = 0;
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(repository.loadForTeam(83), throwsFormatException);
    await expectLater(repository.loadForTeam(83), throwsFormatException);
    expect(repository.cachedTeams.value, isEmpty);
  });
}

Map<String, dynamic> _overviewJson({int teamId = 83}) => {
      'team': {
        'team_id': teamId,
        'name': teamId == 83 ? 'FC Barcelona' : 'Other Team',
        'short_code': null,
        'image_path': null,
      },
      'next_match': null,
      'last_match': null,
      'standing': null,
    };
