import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'support/player_detail_fixture.dart';

void main() {
  test('localized short names use full translations before original names', () {
    final names = FootballNames.fromJson({
      'teams': {'83': 'FC 바르셀로나', '106': '헤타페 CF'},
      'team_short_names': {'83': '바르셀로나'},
      'players': {'184798': '리오넬 메시', '4313': '손흥민'},
      'player_short_names': {'184798': 'L. 메시'},
      'competitions': {'564': '라리가'},
    });
    expect(names.team(83, 'FC Barcelona'), 'FC 바르셀로나');
    expect(names.team(83, 'Barcelona', short: true), '바르셀로나');
    expect(names.team(106, 'Getafe', short: true), '헤타페 CF');
    expect(names.team(999, 'Original'), 'Original');
    expect(names.player(184798, 'Lionel Messi'), '리오넬 메시');
    expect(names.player(184798, 'L. Messi', short: true), 'L. 메시');
    expect(names.player(4313, 'Son', short: true), '손흥민');
    expect(names.player(null, 'Unknown'), 'Unknown');
    expect(names.competition(564, 'La Liga'), '라리가');
    expect(names.competition(999, 'Other Cup'), 'Other Cup');
  });

  test('loads once per language with authentication and retries failures',
      () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) return http.Response('{}', 503);
        return http.Response(
            jsonEncode({
              'teams': {},
              'team_short_names': {},
              'players': {},
              'player_short_names': {},
              'competitions': {'564': '라리가'},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      baseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: () => {'Authorization': 'Bearer session'},
    );
    addTearDown(api.close);
    final repository = FootballNamesRepository(api);
    await expectLater(
        repository.load('ko'), throwsA(isA<http.ClientException>()));
    final first = repository.load('ko');
    final second = repository.load('ko');
    expect(identical(first, second), isTrue);
    expect((await first).competition(564, 'La Liga'), '라리가');
    await repository.load('ja');
    await repository.load('ko');
    expect(requests.map((r) => r.url.path), [
      '/v1/football-names/ko/display',
      '/v1/football-names/ko/display',
      '/v1/football-names/ja/display',
    ]);
    expect(
        requests.every((r) => r.headers['Authorization'] == 'Bearer session'),
        isTrue);
  });

  test('player match keeps competition and opposing team identities', () {
    for (final teamId in [83, 106]) {
      final json = playerDetailJson(playerId: 184798);
      final match = (json['matches'] as List).first as Map<String, dynamic>;
      match.addAll({
        'competition_id': 564,
        'team_id': teamId,
        'home_team_id': 83,
        'away_team_id': 106
      });
      final detail = playerDetailFromJson(json);
      expect(detail.matches.first.competitionId, 564);
      expect(detail.matches.first.opponentTeamId, teamId == 83 ? 106 : 83);
    }
  });
}
