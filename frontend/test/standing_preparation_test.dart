import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/page_refresh.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/competitions/tournament_bracket_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/standings/api/api_standing_repository.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_repository.dart';
import 'package:onetouch/features/api_knockout_bracket.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/standing_features.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/models/team_season_membership.dart';
import 'package:onetouch/screens/TeamScreen_tabs/standing.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  test('bracket coalesces requests and restores each season after restart',
      () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    final pending = Completer<http.Response>();
    final repository = TournamentBracketRepository(
        api: _api((_) {
          requests++;
          return pending.future;
        }),
        cacheStore: store);
    final first = repository.load(2, 100);
    final second = repository.load(2, 100);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    pending.complete(_response(_bracketJson(2, 100)));
    final brackets = await Future.wait([first, second]);
    expect(brackets[0], same(brackets[1]));
    expect(await repository.load(2, 100), same(brackets.first));
    expect(requests, 1);

    final restored = TournamentBracketRepository(
        api: _api((request) async {
          requests++;
          return _response(_bracketJson(2, 200));
        }),
        cacheStore: store);
    expect((await restored.load(2, 100)).stages.first.ties.first.id, '100');
    expect(requests, 1);
    expect((await restored.load(2, 200)).stages.first.ties.first.id, '200');
    expect(restored.cached(2, 100)!.stages.first.ties.first.id, '100');
    expect(requests, 2);
  });

  test('stale bracket remains available while one refresh updates its cache',
      () async {
    final store = MemoryLocalCacheStore();
    await store.write(
        LocalCacheKeys.tournamentBracket(2, 100), _bracketJson(2, 100));
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = TournamentBracketRepository(
        api: _api((_) {
          requests++;
          return response.future;
        }),
        cacheStore: store);
    await withClock(Clock.fixed(DateTime.now().add(const Duration(minutes: 2))),
        () async {
      final old = await repository.load(2, 100);
      expect(await repository.load(2, 100), same(old));
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      final changed = Completer<void>();
      repository.addListener(() => changed.complete());
      response
          .complete(_response(_bracketJson(2, 100)..['status'] = 'finished'));
      await changed.future;
      expect(repository.cached(2, 100)!.status, 'finished');
    });
  });

  test('mismatched bracket is not cached and can be retried', () async {
    var attempts = 0;
    final repository = TournamentBracketRepository(api: _api((_) async {
      attempts++;
      return _response(_bracketJson(2, attempts == 1 ? 200 : 100));
    }));
    await expectLater(repository.load(2, 100), throwsFormatException);
    expect(repository.cached(2, 100), isNull);
    expect((await repository.load(2, 100)).stages.first.ties.first.id, '100');
    expect(attempts, 2);
  });

  testWidgets(
      'cached bracket renders on first frame, never under another season',
      (tester) async {
    final pending = Completer<http.Response>();
    final refreshed = Completer<http.Response>();
    var requests = 0;
    final repository = TournamentBracketRepository(api: _api((request) {
      requests++;
      if (request.url.queryParameters['season_id'] == '200') {
        return pending.future;
      }
      return requests == 1
          ? Future.value(_response(_bracketJson(2, 100)))
          : refreshed.future;
    }));
    await tester.runAsync(() => repository.load(2, 100));
    final refresh = PageRefreshController();
    Widget app(int seasonId) => MaterialApp(
            home: Scaffold(
                body: PageRefreshScope(
          controller: refresh,
          child: SingleChildScrollView(
              child: ApiKnockoutBracket(
                  competitionId: 2,
                  seasonId: seasonId,
                  repository: repository)),
        )));
    await tester.pumpWidget(app(100));
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(
        find.byKey(const ValueKey('bracket-match-card-100')), findsOneWidget);
    await tester.pumpWidget(app(200));
    expect(find.byKey(const ValueKey('bracket-match-card-100')), findsNothing);
    expect(find.byType(FootballLoadingIndicator), findsOneWidget);
    pending.complete(_response(_bracketJson(2, 200)));
    await tester.pump();
    await tester.pumpWidget(app(100));
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(
        find.byKey(const ValueKey('bracket-match-card-100')), findsOneWidget);
    final refreshing = refresh.refresh();
    await tester.pump();
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    final updated = _bracketJson(2, 100);
    updated['stages'][0]['ties'][0]['tie_id'] = 'updated';
    refreshed.complete(_response(updated));
    await tester.pump();
    await refreshing;
    expect(repository.cached(2, 100)!.stages.first.ties.first.id, 'updated');
    await tester.pump();
    expect(find.byKey(const ValueKey('bracket-match-card-updated')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'prepares season, competition and xG selections including after restart',
      (tester) async {
    final oldSeasons = footballCatalog.seasons.value;
    final oldMemberships = footballCatalog.memberships;
    addTearDown(() {
      footballCatalog.seasons.value = oldSeasons;
      footballCatalog.memberships = oldMemberships;
    });
    footballCatalog.seasons.value = const [
      Season(
          seasonId: 28083,
          competitionId: 8,
          name: '2026/2027',
          isCurrent: true),
      Season(
          seasonId: 25583,
          competitionId: 8,
          name: '2025/2026',
          isCurrent: false),
      Season(
          seasonId: 23614,
          competitionId: 8,
          name: '2024/2025',
          isCurrent: false),
      Season(
          seasonId: 26002,
          competitionId: 2,
          name: '2026/2027',
          isCurrent: true),
      Season(
          seasonId: 25580,
          competitionId: 2,
          name: '2025/2026',
          isCurrent: false),
      Season(
          seasonId: 24002,
          competitionId: 2,
          name: '2024/2025',
          isCurrent: false),
    ];
    footballCatalog.memberships = [
      for (final season in footballCatalog.seasons.value)
        TeamSeasonMembership(
            teamId: 9,
            seasonId: season.seasonId,
            competitionId: season.competitionId),
    ];
    final store = MemoryLocalCacheStore();
    final requests = <Uri>[];
    final api = _api((request) async {
      requests.add(request.url);
      final competition = int.parse(request.url.pathSegments[2]);
      final season = int.parse(request.url.queryParameters['season_id']!);
      return _response(request.url.path.endsWith('/bracket')
          ? _bracketJson(competition, season)
          : _standingJson(competition, season,
              xg: request.url.path.endsWith('/xg-standings')));
    });
    for (final restart in [false, true]) {
      final regular = ApiStandingRepository(api: api, cacheStore: store);
      final xg = ApiXgStandingRepository(api: api, cacheStore: store);
      final brackets = TournamentBracketRepository(api: api, cacheStore: store);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StandingTab(
        team: const TeamOverview(
            id: 9, name: 'Team', shortName: 'T', imagePath: ''),
        regularStandingRepository: regular,
        xgStandingRepository: xg,
        bracketRepository: brackets,
      ))));
      await tester.pumpAndSettle();
      expect(xg.cachedForCompetition(8, seasonId: 23614), isNotNull);
      expect(brackets.cached(2, 26002), isNotNull);
      await tester.tap(find.byKey(const ValueKey('standing-view-xg-table')));
      await tester.pump();
      expect(find.byType(FootballLoadingIndicator), findsNothing);
      expect(
          tester
              .widget<XgTable>(find.byType(XgTable))
              .standings
              .single
              .seasonId,
          28083);
      _seasonFilter(tester).onChanged(23614);
      await tester.pump();
      expect(find.byType(FootballLoadingIndicator), findsNothing);
      expect(
          tester
              .widget<XgTable>(find.byType(XgTable))
              .standings
              .single
              .seasonId,
          23614);
      await tester.pumpAndSettle();
      _leagueFilter(tester).onChanged(2);
      await tester.pumpAndSettle();
      // 유럽 대회의 시즌 선택지도 누르기 전에 같은 경로로 준비해요.
      expect(brackets.cached(2, 25580), isNotNull);
      final beforeSwitch = requests.length;
      await tester.tap(find.byKey(const ValueKey('standing-view-bracket')));
      await tester.pump();
      expect(find.byType(FootballLoadingIndicator), findsNothing);
      for (final season in [25580, 26002, 24002]) {
        _seasonFilter(tester).onChanged(season);
        await tester.pump();
        expect(find.byType(FootballLoadingIndicator), findsNothing);
        expect(
            find.byKey(ValueKey('bracket-match-card-$season')), findsOneWidget);
      }
      expect(requests.length, beforeSwitch);
      expect(requests.toSet().length, requests.length,
          reason: '선택과 미리 읽기가 겹쳐도 API는 한 번만 요청해요.');
      expect(requests.length, 12,
          reason: restart ? '재실행 후에는 저장된 데이터를 다시 요청하지 않아요.' : null);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

AppDropdown<int> _seasonFilter(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('standing-season-filter-shell')));
AppDropdown<int> _leagueFilter(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('standing-league-filter-shell')));
ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://api.test/v1/'),
        requestHeaders: () => const {});
http.Response _response(Map<String, dynamic> json) =>
    http.Response(jsonEncode(json), 200);
Map<String, dynamic> _bracketJson(int competition, int season) {
  final json =
      jsonDecode(File('test/fixtures/api_bracket.json').readAsStringSync())
          as Map<String, dynamic>;
  json['competition_id'] = competition;
  json['season_id'] = season;
  json['stages'][0]['ties'][0]['tie_id'] = '$season';
  return json;
}

Map<String, dynamic> _standingJson(int competition, int season,
        {required bool xg}) =>
    {
      'competition_id': competition,
      'season_id': season,
      if (xg) ...{
        'provider': 'understat',
        'xpts_method': 'historical_draw_rate'
      },
      'rows': [
        {
          'position': 1,
          'team_id': 9,
          'team_name': 'Team $season',
          'team_logo': null,
          'matches_played': 3,
          if (xg) ...{
            'xg': 8.125,
            'xga': 2.5,
            'xpts': 7.25
          } else ...{
            'rank_delta': null,
            'won': 2,
            'draw': 1,
            'lost': 0,
            'goals_for': 8,
            'goals_against': 2,
            'goal_diff': 6,
            'points': 7,
            'last5_form': ['W', 'D']
          },
        }
      ],
    };
