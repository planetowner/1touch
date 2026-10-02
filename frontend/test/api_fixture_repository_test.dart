import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  test('requests, maps, and caches a verified team-match page', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/teams/8/matches');
      expect(request.url.queryParameters, {
        'status': 'upcoming',
        'start': '2026-08-01',
        'end': '2026-08-31',
        'limit': '20',
        'offset': '40',
      });
      expect(request.headers['X-User-Id'], '1');
      expect(request.headers['Accept'], 'application/json');
      return http.Response(
        jsonEncode({
          'items': [_fixtureJson()],
          'limit': 20,
          'offset': 40,
        }),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: client,
          baseUri: Uri.parse('http://localhost:8000/v1'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    final loaded = await repository.loadForTeam(
      8,
      status: FixtureStatus.upcoming,
      start: DateTime(2026, 8),
      end: DateTime(2026, 8, 31, 23, 59),
      limit: 20,
      offset: 40,
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.fixtureId, 19712345);
    expect(loaded.single.status, FixtureStatus.upcoming);
    expect(repository.allFixtures, hasLength(1));
    expect(repository.findById(19712345), same(loaded.single));
    expect(repository.fixtures.value, same(repository.allFixtures));
    expect(() => loaded.clear(), throwsUnsupportedError);
  });

  test('merges pages into an immutable chronological cache by fixture ID',
      () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      final fixture = requestCount == 1
          ? _fixtureJson(
              fixtureId: 2,
              startingAt: '2026-09-02 15:00:00',
            )
          : _fixtureJson(
              fixtureId: 1,
              startingAt: '2026-09-01 15:00:00',
            );
      return http.Response(
        jsonEncode({
          'items': [fixture],
          'limit': 1,
          'offset': requestCount - 1,
        }),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: client,
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    await repository.loadForTeam(8, limit: 1);
    await repository.loadForTeam(8, limit: 1, offset: 1);

    expect(
      repository.allFixtures.map((fixture) => fixture.fixtureId),
      [1, 2],
    );
    expect(() => repository.allFixtures.clear(), throwsUnsupportedError);
  });

  test('omits optional filters and sends backend pagination defaults',
      () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters, {
        'limit': '50',
        'offset': '0',
      });
      return http.Response(
        jsonEncode({'items': [], 'limit': 50, 'offset': 0}),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: client,
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    expect(await repository.loadForTeam(8), isEmpty);
  });

  test('rejects HTTP failures and malformed response roots', () async {
    final responses = [
      http.Response('Unavailable', 503),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    await expectLater(
      repository.loadForTeam(8),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.loadForTeam(8),
      throwsFormatException,
    );
    expect(repository.allFixtures, isEmpty);
  });

  test('rejects invalid queries before sending a request', () async {
    var requestCount = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    await expectLater(
      repository.loadForTeam(8, status: FixtureStatus.unknown),
      throwsArgumentError,
    );
    await expectLater(
      repository.loadForTeam(8, limit: 201),
      throwsRangeError,
    );
    await expectLater(
      repository.loadForTeam(8, offset: -1),
      throwsRangeError,
    );
    expect(requestCount, 0);
  });

  test('restores a team page after recreation and separates query keys',
      () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    ApiFixtureRepository repository() => ApiFixtureRepository(
          api: ApiClient(
            client: MockClient((request) async {
              requests++;
              final offset = int.parse(request.url.queryParameters['offset']!);
              return http.Response(
                jsonEncode({
                  'items': [_fixtureJson(fixtureId: 100 + offset)],
                  'limit': 1,
                  'offset': offset,
                }),
                200,
              );
            }),
            baseUri: Uri.parse('http://localhost:8000/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );

    await repository().loadForTeam(8, status: FixtureStatus.upcoming, limit: 1);
    final reader = repository();
    final restored =
        await reader.loadForTeam(8, status: FixtureStatus.upcoming, limit: 1);
    final nextPage = await reader.loadForTeam(
      8,
      status: FixtureStatus.upcoming,
      limit: 1,
      offset: 1,
    );

    expect(restored.single.fixtureId, 100);
    expect(nextPage.single.fixtureId, 101);
    expect(requests, 2);
    expect(
        reader.cachedForTeamMatches(8,
            status: FixtureStatus.upcoming, limit: 1),
        same(restored));
  });

  test('keeps an expired page visible during one background refresh', () async {
    final store = _AgedCacheStore();
    await store.write(
      LocalCacheKeys.teamMatches(8, 'upcoming', null, null, 1, 0),
      {
        'items': [_fixtureJson(fixtureId: 10)],
        'limit': 1,
        'offset': 0
      },
    );
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('http://localhost:8000/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.loadForTeam(8,
        status: FixtureStatus.upcoming, limit: 1);
    final duplicate = await repository.loadForTeam(8,
        status: FixtureStatus.upcoming, limit: 1);
    await Future<void>.delayed(Duration.zero);
    expect(stale.single.fixtureId, 10);
    expect(duplicate, same(stale));
    expect(requests, 1);

    final updated = Completer<void>();
    repository.cachedTeamMatches.addListener(() {
      if (repository
                  .cachedForTeamMatches(8,
                      status: FixtureStatus.upcoming, limit: 1)
                  ?.single
                  .fixtureId ==
              11 &&
          !updated.isCompleted) {
        updated.complete();
      }
    });
    response.complete(http.Response(
      jsonEncode({
        'items': [_fixtureJson(fixtureId: 11)],
        'limit': 1,
        'offset': 0
      }),
      200,
    ));
    await updated.future;
    expect(
        repository
            .cachedForTeamMatches(8, status: FixtureStatus.upcoming, limit: 1)!
            .single
            .fixtureId,
        11);
  });

  test('drops only a corrupt team page and recovers from the API', () async {
    final store = MemoryLocalCacheStore();
    final key = LocalCacheKeys.teamMatches(8, 'past', null, null, 1, 0);
    await store.write(key, {'items': 'bad', 'limit': 1, 'offset': 0});
    await store.write('unrelated', {'value': true});
    var requests = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'items': [_fixtureJson()],
              'limit': 1,
              'offset': 0
            }),
            200,
          );
        }),
        baseUri: Uri.parse('http://localhost:8000/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    expect(
        await repository.loadForTeam(8, status: FixtureStatus.past, limit: 1),
        hasLength(1));
    expect(requests, 1);
    expect((await store.read(key))!.payload, isA<Map>());
    expect(await store.read('unrelated'), isNotNull);
  });

  test('always rechecks a cached live page and retains it when offline',
      () async {
    final store = MemoryLocalCacheStore();
    final live = {..._fixtureJson(fixtureId: 12), 'status': 'live'};
    await store.write(
      LocalCacheKeys.teamMatches(8, 'live', null, null, 1, 0),
      {
        'items': [live],
        'limit': 1,
        'offset': 0
      },
    );
    var requests = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('Offline', 503);
        }),
        baseUri: Uri.parse('http://localhost:8000/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final cached =
        await repository.loadForTeam(8, status: FixtureStatus.live, limit: 1);
    await Future<void>.delayed(Duration.zero);
    expect(cached.single.fixtureId, 12);
    expect(requests, 1);
    expect(
        repository.cachedForTeamMatches(8,
            status: FixtureStatus.live, limit: 1),
        same(cached));
  });

  test('requests, maps, and caches fixture detail', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/fixtures/19712345');
      expect(request.url.queryParameters, isEmpty);
      expect(request.headers['Authorization'], 'Bearer session-token');
      expect(request.headers['Accept'], 'application/json');
      return http.Response(jsonEncode(_fixtureDetailJson()), 200);
    });
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: client,
          baseUri: Uri.parse('http://localhost:8000/v1'),
          requestHeaders: () => const {
                'Authorization': 'Bearer session-token',
              }),
    );

    final detail = await repository.loadDetail(19712345);

    expect(detail.fixture.fixtureId, 19712345);
    expect(detail.venueName, 'Anfield');
    expect(detail.expectedGoals?.homeXg, 1.75);
    expect(detail.pressure.single.pressure, 0.78);
    expect(repository.findById(19712345), same(detail.fixture));
  });

  test('restores detail after recreation and explicit refresh bypasses TTL',
      () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    ApiFixtureRepository repository() => ApiFixtureRepository(
          api: ApiClient(
            client: MockClient((_) async {
              requests++;
              return http.Response(jsonEncode(_fixtureDetailJson()), 200);
            }),
            baseUri: Uri.parse('http://localhost:8000/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );

    await repository().loadDetail(19712345);
    final reader = repository();
    final restored = await reader.loadDetail(19712345);
    expect(restored.venueName, 'Anfield');
    expect(reader.cachedDetail(19712345), same(restored));
    expect(requests, 1);

    await reader.refreshDetail(19712345);
    expect(requests, 2);
  });

  test('keeps expired detail when its background refresh fails', () async {
    final store = _AgedCacheStore();
    await store.write(
        LocalCacheKeys.fixtureDetail(19712345), _fixtureDetailJson());
    var requests = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('Offline', 503);
        }),
        baseUri: Uri.parse('http://localhost:8000/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.loadDetail(19712345);
    expect(stale.venueName, 'Anfield');
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(repository.cachedDetail(19712345), same(stale));
  });

  test('always rechecks restored live detail', () async {
    final store = MemoryLocalCacheStore();
    await store.write(LocalCacheKeys.fixtureDetail(19712345), {
      ..._fixtureDetailJson(),
      'status': 'live',
    });
    var requests = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('Offline', 503);
        }),
        baseUri: Uri.parse('http://localhost:8000/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final restored = await repository.loadDetail(19712345);
    await Future<void>.delayed(Duration.zero);
    expect(restored.fixture.status, FixtureStatus.live);
    expect(requests, 1);
    expect(repository.cachedDetail(19712345), same(restored));
  });

  test('rejects a mismatched fixture-detail identity', () async {
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(_fixtureDetailJson(fixtureId: 9999)),
              200,
            ),
          ),
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadDetail(19712345),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('9999'),
        ),
      ),
    );
    expect(repository.allFixtures, isEmpty);
  });

  test('requests, maps, and caches head-to-head fixtures', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/fixtures/1001/head2head');
      expect(request.url.queryParameters, {'limit': '20'});
      expect(request.headers['X-User-Id'], '1');
      return http.Response(
        jsonEncode({
          'fixture_id': 1001,
          'team_a': 8,
          'team_b': 19,
          'items': [_fixtureJson()],
        }),
        200,
      );
    });
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: client,
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    final loaded = await repository.loadHeadToHead(1001, limit: 20);

    expect(loaded.single.fixtureId, 19712345);
    expect(repository.findById(19712345), same(loaded.single));
    expect(() => loaded.clear(), throwsUnsupportedError);
  });

  test('rejects mismatched head-to-head fixture identities', () async {
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'fixture_id': 9999,
                'team_a': 8,
                'team_b': 19,
                'items': [_fixtureJson()],
              }),
              200,
            ),
          ),
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    await expectLater(
      repository.loadHeadToHead(1001),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('9999'),
        ),
      ),
    );
    expect(repository.allFixtures, isEmpty);
  });

  test('rejects invalid head-to-head limits before requesting', () async {
    var requestCount = 0;
    final repository = ApiFixtureRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {'X-User-Id': '1'}),
    );

    await expectLater(
      repository.loadHeadToHead(1001, limit: 0),
      throwsRangeError,
    );
    await expectLater(
      repository.loadHeadToHead(1001, limit: 51),
      throwsRangeError,
    );
    expect(requestCount, 0);
  });
}

class _AgedCacheStore implements LocalCacheStore {
  final MemoryLocalCacheStore _delegate = MemoryLocalCacheStore();

  @override
  Future<LocalCacheRecord?> read(String key,
      {String scope = LocalCacheScopes.global, int schemaVersion = 1}) async {
    final record =
        await _delegate.read(key, scope: scope, schemaVersion: schemaVersion);
    if (record == null) return null;
    return LocalCacheRecord(
      payload: record.payload,
      savedAt: DateTime.now().toUtc().subtract(const Duration(days: 8)),
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

Map<String, dynamic> _fixtureJson({
  int fixtureId = 19712345,
  String startingAt = '2026-08-29 14:00:00',
}) {
  return {
    'fixture_id': fixtureId,
    'competition_id': 8,
    'season_id': 25583,
    'competition_type': 'league',
    'round_name': '3',
    'stage_id': 77432101,
    'stage_name': 'Regular Season',
    'round_id': 375001,
    'group_id': null,
    'aggregate_id': null,
    'leg': '1/1',
    'venue_id': 206,
    'state_id': 1,
    'state_code': 'NS',
    'state_name': 'Not Started',
    'status': 'upcoming',
    'starting_at': startingAt,
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': null,
    'away_score': null,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/liverpool.png',
    'away_team_logo': null,
  };
}

Map<String, dynamic> _fixtureDetailJson({int fixtureId = 19712345}) {
  return {
    ..._fixtureJson(fixtureId: fixtureId),
    'venue_name': 'Anfield',
    'expected_goals': {
      'home_xg': 1.75,
      'away_xg': 0.82,
      'home_xga': 0.82,
      'away_xga': 1.75,
      'provider': 'understat',
    },
    'player_expected_goals': [],
    'shots': [],
    'events': [],
    'statistics': [],
    'player_statistics': [],
    'lineups': [],
    'formations': [],
    'coaches': [],
    'pressure': [
      {
        'team_id': 8,
        'minute': 27,
        'pressure': 0.78,
      },
    ],
  };
}
