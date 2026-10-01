import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';

void main() {
  test('requests, maps, and caches the current team injury report', () async {
    var requestCount = 0;
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestCount++;
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/teams/83/injuries');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_reportJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(second, same(first));
    expect(first.teamId, 83);
    expect(first.seasonId, 25659);
    expect(first.players.single.injuries, hasLength(2));
    expect(repository.cachedForTeam(83), same(first));
    expect(requestCount, 1);
    expect(
      () => repository.cachedReports.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('supports a trailing base-URI slash and an empty player list', () async {
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/teams/83/injuries');
            return http.Response(
              jsonEncode(_reportJson(players: const [])),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    final report = await repository.loadForTeam(83);

    expect(report.players, isEmpty);
    expect(repository.cachedForTeam(83), same(report));
  });

  test('keeps different teams in separate cache entries', () async {
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
          client: MockClient((request) async {
            final teamId = int.parse(request.url.pathSegments[2]);
            return http.Response(jsonEncode(_reportJson(teamId: teamId)), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(19);

    expect(first.teamId, 83);
    expect(second.teamId, 19);
    expect(repository.cachedReports.value, hasLength(2));
  });

  test('maps not found to an unavailable team feature', () async {
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
          client: MockClient((_) async => http.Response('Not found', 404)),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForTeam(83),
      throwsA(isA<TeamFeatureUnavailableException>()),
    );
    expect(repository.cachedReports.value, isEmpty);
  });

  test('surfaces authentication and server failures', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response('Server error', 500),
    ];
    var requestCount = 0;
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(
        repository.loadForTeam(83),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(repository.cachedReports.value, isEmpty);
  });

  test('rejects malformed and mismatched responses without caching', () async {
    final responses = [
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_reportJson(teamId: 19)), 200),
      http.Response(
        jsonEncode({..._reportJson(), 'season_id': '25659'}),
        200,
      ),
    ];
    var requestCount = 0;
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(repository.loadForTeam(83), throwsFormatException);
    }
    expect(repository.cachedReports.value, isEmpty);
  });

  test('restores a fresh report without requesting the API', () async {
    final store = _SeededInjuryCacheStore(
      payload: _reportJson(),
      savedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
    );
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
        client: MockClient((_) async => throw StateError('Unexpected request')),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final report = await repository.loadForTeam(83);

    expect(report.players, hasLength(1));
    expect(repository.cachedForTeam(83), same(report));
  });

  test('returns stale injuries then publishes a refreshed report', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    var requests = 0;
    final store = _SeededInjuryCacheStore(
      payload: _reportJson(),
      savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          if (!requested.isCompleted) requested.complete();
          return response.future;
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );
    final updated = Completer<void>();
    repository.cachedReports.addListener(() {
      if (repository.cachedForTeam(83)?.players.isEmpty ?? false) {
        updated.complete();
      }
    });

    final stale = await repository.loadForTeam(83);
    await repository.loadForTeam(83);
    await requested.future;
    expect(stale.players, hasLength(1));
    expect(requests, 1);

    response.complete(http.Response(jsonEncode(_reportJson(players: [])), 200));
    await updated.future;
    await store.saved.future;
    expect(repository.cachedForTeam(83)?.players, isEmpty);
    expect((await store.read(LocalCacheKeys.teamInjuries(83)))?.payload,
        isA<Map>());
  });

  test('keeps a stale report when background refresh fails', () async {
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response('Offline', 500)),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: _SeededInjuryCacheStore(
        payload: _reportJson(),
        savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      ),
    );

    final stale = await repository.loadForTeam(83);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(repository.cachedForTeam(83), same(stale));
  });

  test('removes a stale report when the team is no longer supported', () async {
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response('Not found', 404)),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: _SeededInjuryCacheStore(
        payload: _reportJson(),
        savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      ),
    );
    final removed = Completer<void>();
    var hadReport = false;
    repository.cachedReports.addListener(() {
      if (repository.cachedForTeam(83) != null) {
        hadReport = true;
      } else if (hadReport && !removed.isCompleted) {
        removed.complete();
      }
    });

    final stale = await repository.loadForTeam(83);
    expect(stale.players, hasLength(1));
    await removed.future;
    expect(repository.cachedForTeam(83), isNull);
  });

  test('loads injuries even when local cache storage fails', () async {
    final repository = ApiTeamInjuryRepository(
      api: ApiClient(
        client: MockClient(
            (_) async => http.Response(jsonEncode(_reportJson()), 200)),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {},
      ),
      cacheStore: _FailingInjuryCacheStore(),
    );

    final report = await repository.loadForTeam(83);
    expect(report.players, hasLength(1));
    expect(repository.cachedForTeam(83), same(report));
  });
}

class _FailingInjuryCacheStore extends MemoryLocalCacheStore {
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

class _SeededInjuryCacheStore extends MemoryLocalCacheStore {
  _SeededInjuryCacheStore({required this.payload, required this.savedAt});

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
    if (!_restored && key == LocalCacheKeys.teamInjuries(83)) {
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

Map<String, dynamic> _reportJson({
  int teamId = 83,
  List<Map<String, dynamic>>? players,
}) {
  return {
    'team_id': teamId,
    'season_id': 25659,
    'players': players ??
        [
          {
            'player_id': 101,
            'player_name': 'Player 101',
            'player_image': null,
            'jersey_number': null,
            'injuries': [
              {
                'sideline_id': 5001,
                'type_id': 2,
                'type_name': 'Muscle Injury',
                'start_date': '2026-09-01',
                'end_date': '2026-09-20',
              },
              {
                'sideline_id': 5002,
                'type_id': 3,
                'type_name': 'Knock',
                'start_date': '2026-08-15',
                'end_date': null,
              },
            ],
          },
        ],
  };
}
