import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'support/player_detail_fixture.dart';

void main() {
  test(
      'comparison page uses one request and preserves filters and nullable fields',
      () async {
    final sample = jsonDecode(
        File('test/fixtures/api_player_comparison_candidates.json')
            .readAsStringSync()) as Map<String, dynamic>;
    var requests = 0;
    final repo = ApiPlayerDetailRepository(
        api: ApiClient(
      client: MockClient((request) async {
        requests++;
        expect(request.url.path, '/v1/players/comparison-candidates');
        expect(request.url.queryParameters, {
          'q': '이름',
          'position': 'FW',
          'excluded_id': '7',
          'limit': '20',
          'offset': '20',
        });
        return http.Response.bytes(utf8.encode(jsonEncode(sample)), 200);
      }),
      baseUri: Uri.parse('https://example.com/v1/'),
      requestHeaders: () => const {},
    ));
    final page = await repo.comparisonCandidates('이름',
        position: 'FW', excludedId: 7, offset: 20);
    expect(requests, 1);
    expect((page.total, page.limit, page.offset, page.seasonName),
        (22, 20, 20, '2026/2027'));
    expect(page.players.first.player.id, 101);
    expect(page.players.first.position, 'FW');
    expect(page.players.first.teamId, 8);
    expect(page.players.first.teamName, 'Example Club');
    expect(page.players.first.jerseyNumber, 9);
    expect(page.players.last.player.name, '이름 없는 선수');
    expect(page.players.last.player.image, isNull);
    expect(page.players.last.position, isNull);
    expect(page.players.last.teamId, isNull);
    expect(page.players.last.teamName, isNull);
    expect(page.players.last.jerseyNumber, isNull);
  });

  test('comparison page failure propagates instead of becoming an empty result',
      () async {
    final repo = ApiPlayerDetailRepository(
        api: ApiClient(
      client: MockClient((_) async => http.Response('Unavailable', 500)),
      baseUri: Uri.parse('https://example.com/v1/'),
      requestHeaders: () => const {},
    ));
    await expectLater(
        repo.comparisonCandidates(''), throwsA(isA<http.ClientException>()));
  });

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
    expect(detail.profile.nationalityId, 712);
    expect(detail.profile.nationality, 'South Korea');
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
  test('restores player detail for the same player and season after restart',
      () async {
    final store = MemoryLocalCacheStore();
    final seasonId = detailFixture().seasons.last.id;
    var requests = 0;
    ApiPlayerDetailRepository repository() => ApiPlayerDetailRepository(
          api: ApiClient(
            client: MockClient((_) async {
              requests++;
              return http.Response.bytes(
                  utf8.encode(jsonEncode(
                      playerDetailJson(playerId: 1, seasonId: seasonId))),
                  200);
            }),
            baseUri: Uri.parse('https://example.com/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );

    await repository().load(1, seasonId: seasonId);
    final restored = await repository().restoreFor(1, seasonId: seasonId);
    expect(restored?.data.playerId, 1);
    expect(restored?.data.selectedSeason?.id, seasonId);
    expect(requests, 1);
    expect(await repository().restoreFor(2, seasonId: seasonId), isNull);
    expect(await repository().restoreFor(1), isNull);

    await store.clearScope(LocalCacheScopes.global);
    expect(await repository().restoreFor(1, seasonId: seasonId), isNull);
  });

  test('discards a malformed cached player detail', () async {
    final store = MemoryLocalCacheStore();
    final key = LocalCacheKeys.playerDetail(1, null);
    await store.write(key, {'player_id': 1});
    final repository = ApiPlayerDetailRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUri: Uri.parse('https://example.com/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    expect(await repository.restoreFor(1), isNull);
    expect(await store.read(key), isNull);
  });
  test('zero stays zero and whole numbers retain trailing zeros', () {
    expect(playerNumber(0), '0');
    expect(playerNumber(10, decimals: 0), '10');
    expect(playerNumber(20.5), '20.5');
    expect(playerNumber(null), '—');
  });
}
