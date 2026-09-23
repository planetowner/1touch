import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_repository.dart';

void main() {
  group('loadOptionsForTeam', () {
    test('requests and maps the available attribute seasons', () async {
      final repository = ApiTeamAttributeRepository(
        api: ApiClient(
            client: MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, '/v1/teams/83/attributes/options');
              expect(request.url.queryParameters, isEmpty);
              expect(request.headers['Accept'], 'application/json');
              expect(request.headers['Authorization'], 'Bearer session-token');
              return http.Response(
                jsonEncode({
                  'team_id': 83,
                  'items': [
                    {
                      'competition_id': 564,
                      'season_id': 25659,
                      'season_name': '2025/2026',
                      'is_current': true,
                    },
                    {
                      'competition_id': 564,
                      'season_id': 23621,
                      'season_name': '2024/2025',
                      'is_current': false,
                    },
                  ],
                }),
                200,
              );
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {
                  'Authorization': 'Bearer session-token',
                }),
      );

      final result = await repository.loadOptionsForTeam(83);

      expect(result, hasLength(2));
      expect(result.first.competitionId, 564);
      expect(result.first.seasonId, 25659);
      expect(result.first.seasonName, '2025/2026');
      expect(result.first.isCurrent, isTrue);
      expect(result.last.seasonId, 23621);
      expect(result.last.isCurrent, isFalse);
      expect(() => result.clear(), throwsUnsupportedError);
    });

    test('rejects options returned for another team', () async {
      final repository = ApiTeamAttributeRepository(
        api: ApiClient(
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({'team_id': 19, 'items': []}),
                200,
              ),
            ),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      await expectLater(
        repository.loadOptionsForTeam(83),
        throwsFormatException,
      );
    });

    test('rejects malformed option responses', () async {
      final responses = [
        http.Response(jsonEncode([]), 200),
        http.Response(jsonEncode({'team_id': 83, 'items': 'invalid'}), 200),
        http.Response(
          jsonEncode({
            'team_id': 83,
            'items': [
              {
                'competition_id': 564,
                'season_id': 25659,
                'season_name': '2025/2026',
                'is_current': 1,
              },
            ],
          }),
          200,
        ),
      ];
      var requestCount = 0;
      final repository = ApiTeamAttributeRepository(
        api: ApiClient(
            client: MockClient((_) async => responses[requestCount++]),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      for (var i = 0; i < responses.length; i++) {
        await expectLater(
          repository.loadOptionsForTeam(83),
          throwsFormatException,
        );
      }
    });

    test('surfaces option HTTP failures', () async {
      final repository = ApiTeamAttributeRepository(
        api: ApiClient(
            client: MockClient((_) async => http.Response('Unauthorized', 401)),
            baseUri: Uri.parse('https://api.1touch.football/v1'),
            requestHeaders: () => const {}),
      );

      await expectLater(
        repository.loadOptionsForTeam(83),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  test('requests and maps current attributes for the requested team', () async {
    final repository = ApiTeamAttributeRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/teams/83/attributes');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_attributeJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {
                'Authorization': 'Bearer session-token',
              }),
    );

    final result = await repository.loadForTeam(83);

    expect(result, hasLength(1));
    expect(result.single.teamId, 83);
    expect(result.single.seasonId, 27965);
    expect(result.single.radarValues, [79.76, 73.57, 86.39, 72.96, 82.8]);
    expect(() => result.clear(), throwsUnsupportedError);
  });

  test('supports a trailing base-URI slash', () async {
    final repository = ApiTeamAttributeRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/teams/83/attributes');
            return http.Response(jsonEncode(_attributeJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    expect(await repository.loadForTeam(83), hasLength(1));
  });

  test('requests and verifies a historical attribute season', () async {
    final repository = ApiTeamAttributeRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/teams/83/attributes');
            expect(request.url.queryParameters, {'season_id': '21646'});
            return http.Response(
              jsonEncode(
                _attributeJson(
                  seasonId: 21646,
                  seasonName: '2024/2025',
                  isCurrent: false,
                ),
              ),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    final result = await repository.loadForTeam(83, seasonId: 21646);

    expect(result.single.seasonId, 21646);
    expect(result.single.seasonLabel, '2024/2025');
  });

  test('rejects a response for a different team', () async {
    final repository = ApiTeamAttributeRepository(
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({..._attributeJson(), 'team_id': 19}),
              200,
            ),
          ),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(repository.loadForTeam(83), throwsFormatException);
  });

  test('rejects a response for a different requested season', () async {
    final repository = ApiTeamAttributeRepository(
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(jsonEncode(_attributeJson()), 200),
          ),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForTeam(83, seasonId: 21646),
      throwsFormatException,
    );
  });

  test('surfaces HTTP failures and malformed response roots', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiTeamAttributeRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(repository.loadForTeam(83), throwsFormatException);
  });
}

Map<String, dynamic> _attributeJson({
  int seasonId = 27965,
  String seasonName = '2026/2027',
  bool isCurrent = true,
}) {
  return {
    'competition_id': 564,
    'season_id': seasonId,
    'season_name': seasonName,
    'is_current': isCurrent,
    'team_id': 83,
    'team_name': 'FC Barcelona',
    'model_id': 1,
    'possession_build_up': 82.8,
    'attacking_threat': 73.57,
    'chance_creation': 86.39,
    'finishing': 79.76,
    'defending': 72.96,
    'attributes_updated_at': '2026-09-12T14:02:20Z',
  };
}
