import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
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

  test('restores a fresh overview after repository recreation', () async {
    final store = MemoryLocalCacheStore();
    final writer = ApiTeamOverviewRepository(
      api: ApiClient(
        client: MockClient(
          (_) async => http.Response(jsonEncode(_overviewJson()), 200),
        ),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );
    await writer.loadForTeam(83);

    var requested = false;
    final reader = ApiTeamOverviewRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requested = true;
          return http.Response('Unexpected request', 500);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final restored = await reader.loadForTeam(83);

    expect(restored.name, 'FC Barcelona');
    expect(reader.cachedForTeam(83), same(restored));
    expect(requested, isFalse);
  });

  test('returns stale data then publishes one background refresh', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    var requestCount = 0;
    final store = _SeededTeamOverviewCacheStore(
      payload: _overviewJson(),
      savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
        client: MockClient((_) {
          requestCount++;
          if (!requested.isCompleted) requested.complete();
          return response.future;
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );
    final updated = Completer<void>();
    repository.cachedTeams.addListener(() {
      if (repository.cachedForTeam(83)?.name == 'Refreshed Team' &&
          !updated.isCompleted) {
        updated.complete();
      }
    });

    final stale = await repository.loadForTeam(83);
    final duplicate = await repository.loadForTeam(83);
    await requested.future;

    expect(stale.name, 'FC Barcelona');
    expect(duplicate, same(stale));
    expect(requestCount, 1);

    response.complete(
      http.Response(
        jsonEncode(_overviewJson(name: 'Refreshed Team')),
        200,
      ),
    );
    await updated.future;
    await store.saved.future;

    expect(repository.cachedForTeam(83)?.name, 'Refreshed Team');
  });

  test('keeps stale data when its background refresh fails', () async {
    final requested = Completer<void>();
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requested.complete();
          return http.Response('Offline', 500);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: _SeededTeamOverviewCacheStore(
        payload: _overviewJson(),
        savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      ),
    );

    final stale = await repository.loadForTeam(83);
    await requested.future;
    await Future<void>.delayed(Duration.zero);

    expect(repository.cachedForTeam(83), same(stale));
  });

  test('deletes a corrupt overview and recovers it from the API', () async {
    final store = MemoryLocalCacheStore();
    await store.write(LocalCacheKeys.teamOverview(83), {'team': 'invalid'});
    await store.write('unrelated', {'value': true});
    var requestCount = 0;
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requestCount++;
          return http.Response(jsonEncode(_overviewJson()), 200);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final overview = await repository.loadForTeam(83);

    expect(overview.name, 'FC Barcelona');
    expect(requestCount, 1);
    expect(
      (await store.read(LocalCacheKeys.teamOverview(83)))?.payload,
      _overviewJson(),
    );
    expect((await store.read('unrelated'))?.payload, {'value': true});
  });

  test('loads from the API when local cache storage fails', () async {
    final repository = ApiTeamOverviewRepository(
      api: ApiClient(
        client: MockClient(
          (_) async => http.Response(jsonEncode(_overviewJson()), 200),
        ),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: _FailingTeamOverviewCacheStore(),
    );

    final overview = await repository.loadForTeam(83);

    expect(overview.name, 'FC Barcelona');
    expect(repository.cachedForTeam(83), same(overview));
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

class _FailingTeamOverviewCacheStore extends MemoryLocalCacheStore {
  @override
  Future<LocalCacheRecord?> read(
    String key, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async =>
      throw StateError('Storage unavailable');

  @override
  Future<void> write(
    String key,
    Object payload, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async =>
      throw StateError('Storage unavailable');
}

class _SeededTeamOverviewCacheStore extends MemoryLocalCacheStore {
  _SeededTeamOverviewCacheStore({
    required this.payload,
    required this.savedAt,
  });

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
    if (!_restored && key == LocalCacheKeys.teamOverview(83)) {
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

Map<String, dynamic> _overviewJson({
  int teamId = 83,
  String? name,
}) =>
    {
      'team': {
        'team_id': teamId,
        'name': name ?? (teamId == 83 ? 'FC Barcelona' : 'Other Team'),
        'short_code': null,
        'image_path': null,
      },
      'next_match': null,
      'last_match': null,
      'standing': null,
    };
