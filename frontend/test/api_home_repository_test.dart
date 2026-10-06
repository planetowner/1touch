import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/home/api/api_home_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';

void main() {
  test('returns current highlights but never reuses them from memory or disk',
      () async {
    final store = MemoryLocalCacheStore();
    final repository = ApiHomeRepository(
      api: ApiClient(
        client: MockClient((_) async =>
            http.Response(jsonEncode(_homeJson(calendar: const [])), 200)),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );
    final month = DateTime(2026, 9);
    final result = await repository.load(
      teamId: 8,
      start: month,
      end: DateTime(2026, 9, 30),
    );
    expect(result.highlights, hasLength(1));
    final snapshot = repository.snapshotFor(teamId: 8, month: month)!;
    expect(snapshot.data.highlights, isEmpty);
    expect(snapshot.requiresRefresh, isTrue);
    final stored = await store.read(LocalCacheKeys.home(8, month),
        scope: LocalCacheScopes.authenticatedUser);
    expect((stored!.payload as Map)['highlights'], isNull);
  });

  test('maps the viewed team position and signed movement from Home', () async {
    final payload = _homeJson(calendar: const []);
    payload['standing'] = {
      'team_id': 8,
      'team_name': 'Liverpool',
      'team_logo': null,
      'position': 2,
      'rank_delta': -1,
      'matches_played': 5,
      'won': 4,
      'draw': 0,
      'lost': 1,
      'goals_for': 12,
      'goals_against': 5,
      'goal_diff': 7,
      'points': 12,
      'last5_form': ['W', 'W', 'W', 'L', 'W'],
    };
    final repository = ApiHomeRepository(
      api: ApiClient(
        client:
            MockClient((_) async => http.Response(jsonEncode(payload), 200)),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );
    final home = await repository.load();
    expect(home.leaguePosition, 2);
    expect(home.leagueRankDelta, -1);
  });

  test('views another team using only a Home GET request', () async {
    final requests = <http.Request>[];
    final payload = _homeJson(calendar: const []);
    payload['favorite_team'] = _teamJson(19, 'Arsenal', 'ARS');
    payload['highlights'] = null;
    final repository = ApiHomeRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(payload), 200);
        }),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final home = await repository.load(teamId: 19);

    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/v1/home');
    expect(requests.single.url.queryParameters, {'team_id': '19'});
    expect(home.favoriteTeam.teamId, 19);
  });

  test('requests and maps Home with a UTC calendar boundary envelope',
      () async {
    final repository = ApiHomeRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/home');
            expect(request.url.queryParameters, {
              'start': '2026-08-31',
              'end': '2026-10-01',
            });
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_homeJson()), 200);
          }),
          baseUri: Uri.parse('http://localhost:8000/v1'),
          requestHeaders: () => const {
                'Authorization': 'Bearer session-token',
              }),
    );

    final home = await repository.load(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );

    expect(home.favoriteTeam.teamId, 8);
    expect(home.followingTeams.map((team) => team.teamId), [8, 19]);
    expect(home.calendar.single.fixture.fixtureId, 1003);
    expect(home.calendar.single.fixture.kickoff, DateTime.utc(2026, 9, 1));
    expect(home.calendar.single.opponent.name, 'Arsenal');
    expect(home.highlights.single.title, 'Liverpool highlights');
  });

  test('omits date parameters and supports a trailing base-URI slash',
      () async {
    final repository = ApiHomeRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/home');
            expect(request.url.queryParameters, isEmpty);
            return http.Response(
                jsonEncode(_homeJson(calendar: const [])), 200);
          }),
          baseUri: Uri.parse('http://localhost:8000/v1/'),
          requestHeaders: () => const {}),
    );

    final home = await repository.load();

    expect(home.calendar, isEmpty);
  });

  test('pads whichever optional date boundary is supplied', () async {
    var requestCount = 0;
    final repository = ApiHomeRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestCount++;
            expect(
              request.url.queryParameters,
              requestCount == 1
                  ? {'start': '2026-08-31'}
                  : {'end': '2026-10-01'},
            );
            return http.Response(
                jsonEncode(_homeJson(calendar: const [])), 200);
          }),
          baseUri: Uri.parse('http://localhost:8000/v1'),
          requestHeaders: () => const {}),
    );

    await repository.load(start: DateTime(2026, 9, 1));
    await repository.load(end: DateTime(2026, 9, 30));

    expect(requestCount, 2);
  });

  test('keeps successful Home snapshots by team and month', () async {
    final repository = ApiHomeRepository(
      api: ApiClient(
        client: MockClient((request) async {
          final teamId = int.parse(request.url.queryParameters['team_id']!);
          final payload = _homeJson(calendar: const []);
          payload['favorite_team'] = _teamJson(teamId, 'Team $teamId', 'T');
          return http.Response(jsonEncode(payload), 200);
        }),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final september = DateTime(2026, 9);
    expect(repository.snapshotFor(teamId: 8, month: september), isNull);
    await repository.load(
      teamId: 8,
      start: september,
      end: DateTime(2026, 9, 30),
    );
    expect(
        repository
            .snapshotFor(teamId: 8, month: september)
            ?.data
            .favoriteTeam
            .teamId,
        8);
    expect(repository.snapshotFor(teamId: 19, month: september), isNull);
    expect(
        repository.snapshotFor(teamId: 8, month: DateTime(2026, 10)), isNull);

    repository.clearSnapshots();
    expect(repository.snapshotFor(teamId: 8, month: september), isNull);
  });

  test(
      'restores Home from authenticated local storage after repository restart',
      () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    ApiHomeRepository repository() => ApiHomeRepository(
          api: ApiClient(
            client: MockClient((_) async {
              requests++;
              return http.Response(
                  jsonEncode(_homeJson(calendar: const [])), 200);
            }),
            baseUri: Uri.parse('https://api.example.test/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );
    final month = DateTime(2026, 9);
    await repository().load(
      teamId: 8,
      start: month,
      end: DateTime(2026, 9, 30),
    );
    final restored = await repository().restoreFor(teamId: 8, month: month);

    expect(restored?.data.favoriteTeam.teamId, 8);
    expect(restored?.data.highlights, isEmpty);
    expect(restored?.requiresRefresh, isTrue);
    expect(restored?.savedAt.isAfter(DateTime(2026)), isTrue);
    expect(requests, 1);
    expect(await repository().restoreFor(teamId: 8, month: DateTime(2026, 10)),
        isNull);

    await store.clearScope(LocalCacheScopes.authenticatedUser);
    expect(await repository().restoreFor(teamId: 8, month: month), isNull);
  });

  test('drops a malformed stored Home response', () async {
    final store = MemoryLocalCacheStore();
    final month = DateTime(2026, 9);
    final key = LocalCacheKeys.home(8, month);
    await store.write(key, {'favorite_team': null},
        scope: LocalCacheScopes.authenticatedUser);
    final repository = ApiHomeRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    expect(await repository.restoreFor(teamId: 8, month: month), isNull);
    expect(await store.read(key, scope: LocalCacheScopes.authenticatedUser),
        isNull);
  });

  test('does not restore an old session response after snapshots are cleared',
      () async {
    final response = Completer<http.Response>();
    final repository = ApiHomeRepository(
      api: ApiClient(
        client: MockClient((_) => response.future),
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );
    final month = DateTime(2026, 9);
    final request = repository.load(
      teamId: 8,
      start: month,
      end: DateTime(2026, 9, 30),
    );
    repository.clearSnapshots();
    response.complete(
        http.Response(jsonEncode(_homeJson(calendar: const [])), 200));
    await request;
    expect(repository.snapshotFor(teamId: 8, month: month), isNull);
  });

  test('surfaces HTTP failures and malformed response roots', () async {
    final responses = [
      http.Response('Unavailable', 503),
      http.Response(jsonEncode([]), 200),
    ];
    var requestCount = 0;
    final repository = ApiHomeRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('http://localhost:8000/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(repository.load(), throwsA(isA<http.ClientException>()));
    await expectLater(repository.load(), throwsFormatException);
  });

  test('accepts the country determined by the server', () async {
    final payload = _homeJson();
    (payload['highlights'] as Map<String, dynamic>)['viewer_country'] = 'KR';
    final repository = ApiHomeRepository(
      api: ApiClient(
          client:
              MockClient((_) async => http.Response(jsonEncode(payload), 200)),
          baseUri: Uri.parse('https://api.example.test/v1/'),
          requestHeaders: () => const {}),
    );

    expect((await repository.load()).highlights.single.title,
        'Liverpool highlights');
  });
}

Map<String, dynamic> _homeJson({List<Map<String, dynamic>>? calendar}) {
  return {
    'favorite_team': _teamJson(8, 'Liverpool', 'LIV'),
    'following_teams': [
      _teamJson(8, 'Liverpool', 'LIV'),
      _teamJson(19, 'Arsenal', 'ARS'),
    ],
    'next_match': null,
    'last_match': null,
    'calendar': calendar ?? [_fixtureJson()],
    'highlights': _highlightsJson(),
  };
}

Map<String, dynamic> _highlightsJson() => {
      'team_id': 8,
      'viewer_country': 'US',
      'updated_at': '2026-09-18T21:00:00Z',
      'items': [
        {
          'video_id': 'video-1',
          'video_url': 'https://www.youtube.com/watch?v=video-1',
          'title': 'Liverpool highlights',
          'thumbnail_url': 'https://i.ytimg.com/video-1.jpg',
          'published_at': '2026-09-18T20:00:00Z',
          'duration_seconds': 420,
          'channel_id': 'channel-1',
          'channel_name': 'Liverpool FC',
          'source_type': 'club',
          'is_extended': false,
          'embeddable': true,
          'match': {
            'match_key': 'sportmonks:1003',
            'fixture_id': 1003,
            'competition_key': 'sportmonks:8',
            'competition_name': 'Premier League',
            'season_name': '2026/2027',
            'starting_at': '2026-09-18T14:00:00Z',
            'home': {'team_id': 8, 'name': 'Liverpool'},
            'away': {'team_id': 19, 'name': 'Arsenal'},
            'record_source': 'sportmonks',
            'record_url': 'https://example.test/fixtures/1003',
          },
        },
      ],
    };

Map<String, dynamic> _teamJson(int id, String name, String shortCode) {
  return {
    'team_id': id,
    'name': name,
    'short_code': shortCode,
    'image_path': 'https://cdn.example/$id.png',
  };
}

Map<String, dynamic> _fixtureJson() {
  return {
    'fixture_id': 1003,
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
    'starting_at': '2026-09-01 00:00:00',
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': null,
    'away_score': null,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/8.png',
    'away_team_logo': 'https://cdn.example/19.png',
  };
}
