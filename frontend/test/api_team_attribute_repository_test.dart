import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_repository.dart';

void main() {
  test('requests and maps current attributes for the requested team', () async {
    final repository = ApiTeamAttributeRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/teams/83/attributes');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_attributeJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {
        'Authorization': 'Bearer session-token',
      },
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
      client: MockClient((request) async {
        expect(request.url.path, '/v1/teams/83/attributes');
        return http.Response(jsonEncode(_attributeJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    expect(await repository.loadForTeam(83), hasLength(1));
  });

  test('rejects a response for a different team', () async {
    final repository = ApiTeamAttributeRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({..._attributeJson(), 'team_id': 19}),
          200,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.loadForTeam(83), throwsFormatException);
  });

  test('surfaces HTTP failures and malformed response roots', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiTeamAttributeRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(repository.loadForTeam(83), throwsFormatException);
  });
}

Map<String, dynamic> _attributeJson() {
  return {
    'competition_id': 564,
    'season_id': 27965,
    'season_name': '2026/2027',
    'is_current': true,
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
