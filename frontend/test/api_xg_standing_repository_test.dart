import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_repository.dart';

void main() {
  test('requests, maps, and caches an explicit competition season', () async {
    var requestCount = 0;
    final repository = ApiXgStandingRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestCount++;
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/competitions/8/xg-standings');
            expect(request.url.queryParameters, {'season_id': '25583'});
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_responseJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final first = await repository.loadForCompetition(8, seasonId: 25583);
    final second = await repository.loadForCompetition(8, seasonId: 25583);

    expect(first.single.teamName, 'Manchester City');
    expect(first.single.xptsMethod, 'historical_draw_rate');
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
    final repository = ApiXgStandingRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.queryParameters, isEmpty);
            return http.Response(jsonEncode(_responseJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
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
    final repository = ApiXgStandingRepository(
      api: ApiClient(
          client: MockClient((request) async {
            final competitionId = int.parse(request.url.pathSegments[2]);
            final seasonId =
                int.parse(request.url.queryParameters['season_id']!);
            return http.Response(
              jsonEncode(_responseJson(
                competitionId: competitionId,
                seasonId: seasonId,
              )),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await repository.loadForCompetition(8, seasonId: 25583);
    await repository.loadForCompetition(8, seasonId: 23614);
    await repository.loadForCompetition(564, seasonId: 25659);

    expect(repository.cachedTables.value, hasLength(3));
    expect(repository.allXgStandings, hasLength(3));
  });

  test('deduplicates simultaneous requests for the same query', () async {
    var requestCount = 0;
    final response = Completer<http.Response>();
    final repository = ApiXgStandingRepository(
      api: ApiClient(
          client: MockClient((_) {
            requestCount++;
            return response.future;
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final firstLoad = repository.loadForCompetition(8, seasonId: 25583);
    final secondLoad = repository.loadForCompetition(8, seasonId: 25583);

    await Future<void>.delayed(Duration.zero);
    expect(requestCount, 1);
    response.complete(http.Response(jsonEncode(_responseJson()), 200));
    final results = await Future.wait([firstLoad, secondLoad]);

    expect(results[1], same(results[0]));
    expect(requestCount, 1);
  });

  test('does not deduplicate different xG standing queries', () async {
    var requestCount = 0;
    final responses = <int, Completer<http.Response>>{};
    final repository = ApiXgStandingRepository(
      api: ApiClient(
          client: MockClient((request) {
            requestCount++;
            final seasonId =
                int.parse(request.url.queryParameters['season_id']!);
            return responses
                .putIfAbsent(seasonId, () => Completer<http.Response>())
                .future;
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final firstLoad = repository.loadForCompetition(8, seasonId: 25583);
    final secondLoad = repository.loadForCompetition(8, seasonId: 23614);

    await Future<void>.delayed(Duration.zero);
    expect(requestCount, 2);
    responses[25583]!.complete(
      http.Response(jsonEncode(_responseJson()), 200),
    );
    responses[23614]!.complete(
      http.Response(jsonEncode(_responseJson(seasonId: 23614)), 200),
    );
    await Future.wait([firstLoad, secondLoad]);

    expect(requestCount, 2);
  });

  test('restores a fresh xG table after repository recreation', () async {
    final store = MemoryLocalCacheStore();
    final writer = ApiXgStandingRepository(
      api: _api((_) async => http.Response(jsonEncode(_responseJson()), 200)),
      cacheStore: store,
    );
    await writer.loadForCompetition(8, seasonId: 25583);

    var requested = false;
    final reader = ApiXgStandingRepository(
      api: _api((_) async {
        requested = true;
        return http.Response('Unexpected request', 500);
      }),
      cacheStore: store,
    );

    final restored = await reader.loadForCompetition(8, seasonId: 25583);

    expect(restored.single.teamName, 'Manchester City');
    expect(requested, isFalse);
  });

  test('returns stale xG then publishes one background refresh', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    var requestCount = 0;
    final store = _SeededXgStandingCacheStore(
      key: LocalCacheKeys.xgStandings(8, 25583),
      payload: _responseJson(),
      savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 7)),
    );
    final repository = ApiXgStandingRepository(
      api: _api((_) {
        requestCount++;
        if (!requested.isCompleted) requested.complete();
        return response.future;
      }),
      cacheStore: store,
    );
    final updated = Completer<void>();
    repository.cachedTables.addListener(() {
      if (repository
              .cachedForCompetition(8, seasonId: 25583)
              ?.single
              .teamName ==
          'Fresh Expected Team') {
        if (!updated.isCompleted) updated.complete();
      }
    });

    final stale = await repository.loadForCompetition(8, seasonId: 25583);
    await repository.loadForCompetition(8, seasonId: 25583);
    await requested.future;

    expect(stale.single.teamName, 'Manchester City');
    expect(requestCount, 1);

    response.complete(http.Response(
      jsonEncode(_responseJson(teamName: 'Fresh Expected Team')),
      200,
    ));
    await updated.future;
    await store.saved.future;
    expect(
      repository.cachedForCompetition(8, seasonId: 25583)?.single.teamName,
      'Fresh Expected Team',
    );
  });

  test('keeps stale xG when background refresh fails', () async {
    final requested = Completer<void>();
    final repository = ApiXgStandingRepository(
      api: _api((_) async {
        requested.complete();
        return http.Response('Offline', 500);
      }),
      cacheStore: _SeededXgStandingCacheStore(
        key: LocalCacheKeys.xgStandings(8, 25583),
        payload: _responseJson(),
        savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 7)),
      ),
    );

    final stale = await repository.loadForCompetition(8, seasonId: 25583);
    await requested.future;
    await Future<void>.delayed(Duration.zero);

    expect(repository.cachedForCompetition(8, seasonId: 25583), same(stale));
  });

  test('manual xG refresh bypasses a fresh cache', () async {
    var requestCount = 0;
    final store = MemoryLocalCacheStore();
    await store.write(
      LocalCacheKeys.xgStandings(8, 25583),
      _responseJson(),
    );
    final repository = ApiXgStandingRepository(
      api: _api((_) async {
        requestCount++;
        return http.Response(
          jsonEncode(_responseJson(teamName: 'Forced Expected Team')),
          200,
        );
      }),
      cacheStore: store,
    );
    await repository.loadForCompetition(8, seasonId: 25583);

    final refreshed =
        await repository.refreshForCompetition(8, seasonId: 25583);

    expect(refreshed.single.teamName, 'Forced Expected Team');
    expect(requestCount, 1);
  });

  test('deletes corrupt xG and recovers it from the API', () async {
    final store = MemoryLocalCacheStore();
    await store.write(
      LocalCacheKeys.xgStandings(8, 25583),
      {'competition_id': 'invalid'},
    );
    await store.write('unrelated', {'value': true});
    var requestCount = 0;
    final repository = ApiXgStandingRepository(
      api: _api((_) async {
        requestCount++;
        return http.Response(jsonEncode(_responseJson()), 200);
      }),
      cacheStore: store,
    );

    final table = await repository.loadForCompetition(8, seasonId: 25583);

    expect(table.single.teamName, 'Manchester City');
    expect(requestCount, 1);
    expect((await store.read('unrelated'))?.payload, {'value': true});
  });

  test('rejects HTTP, malformed, and mismatched responses without caching',
      () async {
    final responses = [
      http.Response('Unsupported competition', 400),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_responseJson(competitionId: 564)), 200),
      http.Response(jsonEncode(_responseJson(seasonId: 23614)), 200),
    ];
    var index = 0;
    final repository = ApiXgStandingRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
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

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      client: MockClient(handler),
      baseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: () => const {},
    );

class _SeededXgStandingCacheStore extends MemoryLocalCacheStore {
  _SeededXgStandingCacheStore({
    required this.key,
    required this.payload,
    required this.savedAt,
  });

  final String key;
  final Map<String, dynamic> payload;
  final DateTime savedAt;
  final Completer<void> saved = Completer<void>();
  bool _restored = false;

  @override
  Future<LocalCacheRecord?> read(
    String key, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async {
    if (!_restored && key == this.key) {
      _restored = true;
      return LocalCacheRecord(
        payload: payload,
        savedAt: savedAt,
        schemaVersion: schemaVersion,
      );
    }
    return super.read(key, scope: scope, schemaVersion: schemaVersion);
  }

  @override
  Future<void> write(
    String key,
    Object payload, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async {
    await super.write(key, payload, scope: scope, schemaVersion: schemaVersion);
    if (!saved.isCompleted) saved.complete();
  }
}

Map<String, dynamic> _responseJson({
  int competitionId = 8,
  int seasonId = 25583,
  String teamName = 'Manchester City',
}) =>
    {
      'competition_id': competitionId,
      'season_id': seasonId,
      'provider': 'understat',
      'xpts_method': 'historical_draw_rate',
      'rows': [
        {
          'position': 1,
          'team_id': 9,
          'team_name': teamName,
          'team_logo': null,
          'matches_played': 3,
          'xg': 8.125,
          'xga': 2.5,
          'xpts': 7.25,
        },
      ],
    };
