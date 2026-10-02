import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'support/player_directory_fixture.dart';

void main() {
  test(
      'current ranking has no season parameter and preserves paging and filters',
      () async {
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/players/ranking-current');
            expect(request.url.queryParameters, {
              'competition_id': '8',
              'position': 'DF',
              'offset': '100',
              'limit': '100'
            });
            expect(request.headers['Authorization'], 'Bearer test');
            return http.Response(
                jsonEncode({
                  'season_name': '2026/2027',
                  'total': 101,
                  'limit': 100,
                  'offset': 100,
                  'competition_id': 8,
                  'position': 'DF',
                  'leagues': [
                    {
                      'competition_id': 8,
                      'name': 'Premier League',
                      'available_players': 101
                    }
                  ],
                  'items': [
                    {
                      'player_id': 123456,
                      'name': 'Real name',
                      'image': null,
                      'position': 'DF',
                      'rank': 101,
                      'display_score': 74.5,
                      'average_rating': 7.21,
                      'rated_matches': 8
                    }
                  ]
                }),
                200);
          }),
          baseUri: Uri.parse('https://example.test/v1/'),
          requestHeaders: () => const {'Authorization': 'Bearer test'}),
    );
    final result =
        await repository.ranking(league: 8, position: 'DF', offset: 100);
    expect(result.items.single.id, 123456);
    expect(result.items.single.score, 74.5);
  });
  test('ones to watch includes current team and jersey in one request',
      () async {
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/v1/players/ones-to-watch');
          return http.Response(
              jsonEncode({
                'items': [
                  {
                    'player_id': 7,
                    'name': 'Watch player',
                    'image': null,
                    'jersey_number': 17,
                    'team_id': 7980,
                    'team_name': 'Atlético de Madrid',
                    'recent_average': 8.4,
                    'previous_average': 6.2,
                    'change': 2.2,
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final result = await repository.watch();

    expect(result.single.jerseyNumber, 17);
    expect(result.single.teamId, 7980);
    expect(result.single.teamName, 'Atlético de Madrid');
    expect(requests, 1);
  });

  test('restores a current ranking page after repository recreation', () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    ApiPlayerDirectoryRepository repository() => ApiPlayerDirectoryRepository(
          api: ApiClient(
            client: MockClient((_) async {
              requests++;
              return http.Response(jsonEncode(_rankingJson()), 200);
            }),
            baseUri: Uri.parse('https://example.test/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );

    await repository().ranking();
    final reader = repository();
    final restored = await reader.ranking();
    expect(restored.items.single.name, 'Cached player');
    expect(reader.cachedRanking(), same(restored));
    expect(requests, 1);

    await reader.refreshRanking();
    expect(requests, 2);
  });

  test('separates ranking pages by league, position and offset', () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode(_rankingJson(
              league: int.tryParse(
                  request.url.queryParameters['competition_id'] ?? ''),
              position: request.url.queryParameters['position'],
              offset: int.parse(request.url.queryParameters['offset']!),
            )),
            200,
          );
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    await repository.ranking();
    await repository.ranking(league: 8);
    await repository.ranking(position: 'DF');
    await repository.ranking(offset: 100);
    expect(requests, 4);
    expect(repository.cachedRankings.value, hasLength(4));
    expect(
        await store
            .read(LocalCacheKeys.currentPlayerRanking(null, null, 100, 0)),
        isNotNull);
    expect(
        await store.read(LocalCacheKeys.currentPlayerRanking(8, null, 100, 0)),
        isNotNull);
    expect(
        await store
            .read(LocalCacheKeys.currentPlayerRanking(null, 'DF', 100, 0)),
        isNotNull);
    expect(
        await store
            .read(LocalCacheKeys.currentPlayerRanking(null, null, 100, 100)),
        isNotNull);
  });

  test('publishes one background refresh while retaining an expired page',
      () async {
    final store = _AgedRankingStore();
    await store.write(LocalCacheKeys.currentPlayerRanking(null, null, 100, 0),
        _rankingJson());
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.ranking();
    final duplicate = await repository.ranking();
    await Future<void>.delayed(Duration.zero);
    expect(stale.items.single.name, 'Cached player');
    expect(duplicate, same(stale));
    expect(requests, 1);

    final updated = Completer<void>();
    repository.cachedRankings.addListener(() {
      if (repository.cachedRanking()?.items.single.name == 'Fresh player' &&
          !updated.isCompleted) {
        updated.complete();
      }
    });
    response.complete(http.Response(
        jsonEncode(_rankingJson(playerName: 'Fresh player')), 200));
    await updated.future;
    expect(repository.cachedRanking()?.items.single.name, 'Fresh player');
  });

  test('retains an expired page if its refresh fails', () async {
    final store = _AgedRankingStore();
    await store.write(LocalCacheKeys.currentPlayerRanking(null, null, 100, 0),
        _rankingJson());
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('Offline', 503);
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.ranking();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(repository.cachedRanking(), same(stale));
  });

  test('removes a malformed ranking page and recovers from API', () async {
    final store = MemoryLocalCacheStore();
    final key = LocalCacheKeys.currentPlayerRanking(null, null, 100, 0);
    await store.write(key, {'items': 'broken'});
    await store.write('unrelated', {'value': true});
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(_rankingJson()), 200);
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    expect((await repository.ranking()).items, hasLength(1));
    expect(requests, 1);
    expect(await store.read(key), isNotNull);
    expect(await store.read('unrelated'), isNotNull);
  });

  test('rejects a ranking page for another filter', () async {
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode(_rankingJson(league: 82)),
              200,
            )),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );

    await expectLater(repository.ranking(league: 8), throwsFormatException);
    expect(repository.cachedRanking(league: 8), isNull);
  });

  test('deduplicates concurrent ranking loads and forced refresh', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final first = repository.ranking();
    final second = repository.ranking();
    await Future<void>.delayed(Duration.zero);
    final refresh = repository.refreshRanking();
    expect(requests, 1);
    response.complete(http.Response(jsonEncode(_rankingJson()), 200));
    final results = await Future.wait([first, second, refresh]);
    expect(results[0], same(results[1]));
    expect(results[0], same(results[2]));
  });
  test('favorite toggle first loads order and leaves list unchanged on failure',
      () async {
    final repository = FakeFollowingPlayersRepository();
    final controller = PlayerFollowingController(repository: repository);
    await controller.toggle(2);
    expect(repository.saved, [1, 2]);
    expect(controller.players.last.name, 'Saved player 2');
    repository.fail = true;
    await expectLater(controller.toggle(1), throwsStateError);
    expect(controller.players.map((p) => p.playerId), [1, 2]);
    repository.fail = false;
    await controller.load();
    expect(controller.error, isNull);
  });
}

Map<String, dynamic> _rankingJson({
  int? league,
  String? position,
  int offset = 0,
  String playerName = 'Cached player',
}) =>
    {
      'season_name': '2026/2027',
      'total': 101,
      'limit': 100,
      'offset': offset,
      'competition_id': league,
      'position': position,
      'leagues': [
        {
          'competition_id': 8,
          'name': 'Premier League',
          'available_players': 101
        }
      ],
      'items': [
        {
          'player_id': 101,
          'name': playerName,
          'image': null,
          'position': 'DF',
          'rank': offset + 1,
          'display_score': 74.5,
          'average_rating': 7.21,
          'rated_matches': 8,
        }
      ],
    };

class _AgedRankingStore implements LocalCacheStore {
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
