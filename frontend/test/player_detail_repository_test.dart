import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'support/player_detail_fixture.dart';

void main() {
  test('detail request preserves player/season identity and nulls', () async {
    final seasonId = detailFixture().seasons.last.id;
    final repo = ApiPlayerDetailRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/players/1/detail');
            expect(request.url.queryParameters, {'season_id': '$seasonId'});
            expect(request.headers['Authorization'], 'Bearer test');
            return http.Response(
                jsonEncode(playerDetailJson(playerId: 1, seasonId: seasonId)),
                200,
                headers: {'content-type': 'application/json'});
          }),
          baseUri: Uri.parse('https://example.com/v1/'),
          requestHeaders: () => const {'Authorization': 'Bearer test'}),
    );
    final detail = await repo.load(1, seasonId: seasonId);
    expect(detail.selectedSeason?.id, seasonId);
    expect(detail.profile.image, isNull);
    expect(detail.matches.first.metrics.map((m) => m.code),
        ['goals', 'assists', 'shots']);
    expect(detail.matches.first.metrics[1].value, isNull);
    expect(playerMetricValue(detail.matches.first.metrics[1]), '—');
    expect(detail.honours, isEmpty);
  });
  test('wrong player and request failures never become mock records', () async {
    for (final status in [200, 401, 404, 500]) {
      final repo = ApiPlayerDetailRepository(
        api: ApiClient(
            client: MockClient((_) async => http.Response(
                jsonEncode(playerDetailJson(playerId: 2)), status)),
            baseUri: Uri.parse('https://example.com/v1/'),
            requestHeaders: () => const {}),
      );
      await expectLater(repo.load(1), throwsA(anything));
    }
  });
  test('zero stays zero and whole numbers retain trailing zeros', () {
    expect(playerNumber(0), '0');
    expect(playerNumber(10, decimals: 0), '10');
    expect(playerNumber(20.5), '20.5');
    expect(playerNumber(null), '—');
  });
}
