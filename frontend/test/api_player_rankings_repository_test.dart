import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_rankings_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/player_rankings.dart';

void main() {
  test('requests and maps one rankings page', () async {
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/players/rankings');
            expect(request.url.queryParameters, {
              'season_id': '28083',
              'limit': '20',
              'offset': '0',
            });
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_rankingsJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final page = await repository.load(seasonId: 28083);

    expect(page.competitionId, 8);
    expect(page.seasonName, '2026/2027');
    expect(page.method, PlayerRankingMethod.cumulativeAllLeaguesPercentile);
    expect(page.reference.competitionIds, [8, 82, 301, 384, 564]);
    expect(page.reference.updatedAt, DateTime.utc(2026, 9, 1, 12));
    expect(page.items.single.playerImage, isNull);
    expect(page.items.single.updatedAt, DateTime.utc(2026, 9, 18, 20));
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('validates request arguments before sending HTTP', () async {
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(repository.load(seasonId: 0), throwsRangeError);
    await expectLater(
      repository.load(seasonId: 1, limit: 101),
      throwsRangeError,
    );
    await expectLater(
      repository.load(seasonId: 1, offset: -1),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects HTTP, malformed, and mismatched responses', () async {
    final mismatched = _rankingsJson()..['season_id'] = 999;
    final invalidMethod = _rankingsJson()..['method'] = 'live_percentile';
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(mismatched), 200),
      http.Response(jsonEncode(invalidMethod), 200),
    ];
    var index = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.load(seasonId: 28083),
      throwsA(isA<http.ClientException>()),
    );
    for (var i = 1; i < responses.length; i++) {
      await expectLater(
        repository.load(seasonId: 28083),
        throwsFormatException,
      );
    }
  });

  test('restores a fresh page after recreation without HTTP', () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    ApiPlayerRankingsRepository repository() => ApiPlayerRankingsRepository(
          api: ApiClient(
            client: MockClient((_) async {
              requests++;
              return http.Response(jsonEncode(_rankingsJson()), 200);
            }),
            baseUri: Uri.parse('https://api.1touch.football/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );

    await repository().load(seasonId: 28083);
    final reader = repository();
    final restored = await reader.load(seasonId: 28083);
    expect(restored.items.single.playerName, 'Player One');
    expect(reader.cachedFor(seasonId: 28083), same(restored));
    expect(requests, 1);

    await reader.refresh(seasonId: 28083);
    expect(requests, 2);
  });

  test('separates pages by season, limit and offset', () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests++;
          final season = int.parse(request.url.queryParameters['season_id']!);
          final limit = int.parse(request.url.queryParameters['limit']!);
          final offset = int.parse(request.url.queryParameters['offset']!);
          return http.Response(
            jsonEncode(
                _rankingsJson(seasonId: season, limit: limit, offset: offset)),
            200,
          );
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    await repository.load(seasonId: 28083);
    await repository.load(seasonId: 28083, limit: 10);
    await repository.load(seasonId: 28083, offset: 20);
    await repository.load(seasonId: 28084);

    expect(requests, 4);
    expect(repository.cachedPages.value, hasLength(4));
    expect(await store.read(LocalCacheKeys.playerRankings(28083, 20, 0)),
        isNotNull);
    expect(await store.read(LocalCacheKeys.playerRankings(28083, 10, 0)),
        isNotNull);
    expect(await store.read(LocalCacheKeys.playerRankings(28083, 20, 20)),
        isNotNull);
    expect(await store.read(LocalCacheKeys.playerRankings(28084, 20, 0)),
        isNotNull);
  });

  test('returns expired data and deduplicates its background refresh',
      () async {
    final store = _AgedRankingsStore();
    await store.write(
        LocalCacheKeys.playerRankings(28083, 20, 0), _rankingsJson());
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.load(seasonId: 28083);
    final duplicate = await repository.load(seasonId: 28083);
    await Future<void>.delayed(Duration.zero);
    expect(stale.items.single.playerName, 'Player One');
    expect(duplicate, same(stale));
    expect(requests, 1);

    final updated = Completer<void>();
    repository.cachedPages.addListener(() {
      if (repository.cachedFor(seasonId: 28083)?.items.single.playerName ==
              'Player Two' &&
          !updated.isCompleted) {
        updated.complete();
      }
    });
    response.complete(http.Response(
        jsonEncode(_rankingsJson(playerName: 'Player Two')), 200));
    await updated.future;
    expect(repository.cachedFor(seasonId: 28083)?.items.single.playerName,
        'Player Two');
  });

  test('keeps expired data when background refresh fails', () async {
    final store = _AgedRankingsStore();
    await store.write(
        LocalCacheKeys.playerRankings(28083, 20, 0), _rankingsJson());
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('Offline', 503);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.load(seasonId: 28083);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(repository.cachedFor(seasonId: 28083), same(stale));
  });

  test('deletes only malformed cache and recovers from HTTP', () async {
    final store = MemoryLocalCacheStore();
    final key = LocalCacheKeys.playerRankings(28083, 20, 0);
    await store.write(key, {'season_id': 28083, 'items': 'broken'});
    await store.write('unrelated', {'value': true});
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(_rankingsJson()), 200);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    expect((await repository.load(seasonId: 28083)).items, hasLength(1));
    expect(requests, 1);
    expect(await store.read(key), isNotNull);
    expect(await store.read('unrelated'), isNotNull);
  });

  test('deduplicates concurrent cold loads and explicit refresh', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiPlayerRankingsRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final first = repository.load(seasonId: 28083);
    final second = repository.load(seasonId: 28083);
    await Future<void>.delayed(Duration.zero);
    final refresh = repository.refresh(seasonId: 28083);
    expect(requests, 1);
    response.complete(http.Response(jsonEncode(_rankingsJson()), 200));
    final pages = await Future.wait([first, second, refresh]);
    expect(pages[0], same(pages[1]));
    expect(pages[0], same(pages[2]));
  });
}

Map<String, dynamic> _rankingsJson({
  int seasonId = 28083,
  int limit = 20,
  int offset = 0,
  String playerName = 'Player One',
}) =>
    {
      'competition_id': 8,
      'season_id': seasonId,
      'season_name': '2026/2027',
      'method': 'cumulative_all_leagues_percentile',
      'reference': {
        'start_season_name': '2020/2021',
        'end_season_name': '2024/2025',
        'minimum_rated_matches': 10,
        'competition_ids': [8, 82, 301, 384, 564],
        'sample_count': 900,
        'updated_at': '2026-09-01T12:00:00Z',
      },
      'total': 1,
      'limit': limit,
      'offset': offset,
      'items': [
        {
          'rank': 1,
          'player_id': 101,
          'player_name': playerName,
          'player_image': null,
          'rated_matches': 12,
          'average_rating': 7.25,
          'percentile_score': 98.37,
          'display_score': 9.8,
          'updated_at': '2026-09-18T20:00:00+00:00',
        },
      ],
    };

class _AgedRankingsStore implements LocalCacheStore {
  final MemoryLocalCacheStore _delegate = MemoryLocalCacheStore();

  @override
  Future<LocalCacheRecord?> read(String key,
      {String scope = LocalCacheScopes.global, int schemaVersion = 1}) async {
    final record =
        await _delegate.read(key, scope: scope, schemaVersion: schemaVersion);
    if (record == null) return null;
    return LocalCacheRecord(
      payload: record.payload,
      savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      schemaVersion: record.schemaVersion,
    );
  }

  @override
  Future<void> write(String key, Object payload,
          {String scope = LocalCacheScopes.global, int schemaVersion = 1}) =>
      _delegate.write(key, payload, scope: scope, schemaVersion: schemaVersion);

  @override
  Future<void> delete(String key, {String scope = LocalCacheScopes.global}) =>
      _delegate.delete(key, scope: scope);

  @override
  Future<void> clearScope(String scope) => _delegate.clearScope(scope);
}
