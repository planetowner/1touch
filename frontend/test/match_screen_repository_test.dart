import 'support/app_catalog.dart';
import 'dart:async';
import 'package:clock/clock.dart' as time;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/formation_player_positions.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_clock.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/team_best_eleven.dart';
import 'package:onetouch/screens/MatchScreen.dart';
import 'package:onetouch/screens/MatchScreen_tabs/anal.dart';
import 'package:onetouch/screens/MatchScreen_tabs/matchinfo.dart';

void main() {
  setUpAppCatalog();
  testWidgets('search and profile app-bar buttons open their routes',
      (tester) async {
    final repository = _ControlledFixtureRepository();
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      initialLocation: '/home',
      navigatorKey: rootNavigatorKey,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) => Scaffold(
            body: navigationShell,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, __) => Scaffold(
                    body: TextButton(
                      onPressed: () => context.push(
                        '/match/${_fixture.fixtureId}?status=upcoming',
                      ),
                      child: const Text('open-match'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/match/:matchId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) => MatchScreen(
              matchId: state.pathParameters['matchId']!,
              matchStatus: 'upcoming',
              repository: repository),
        ),
        GoRoute(
          path: '/search',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const Scaffold(body: Text('search-route')),
        ),
        GoRoute(
          path: '/profile',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const Scaffold(body: Text('profile-route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open-match'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repository.calls.single.complete(_detail());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('match-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('search-route'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('match-profile-button')));
    await tester.pumpAndSettle();
    expect(find.text('profile-route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'refreshes kickoff, live, paused and finished states without reopening',
      (tester) async {
    final repository = _ControlledFixtureRepository();
    await tester.pumpWidget(MaterialApp(
      home: MatchScreen(
        matchId: '${_fixture.fixtureId}',
        matchStatus: 'upcoming',
        repository: repository,
      ),
    ));
    repository.calls.single
        .complete(_detail(status: FixtureStatus.upcoming, stateId: 1));
    await tester.pump();
    expect(find.text('MATCH PREVIEW'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    expect(repository.calls, hasLength(2));
    // 응답이 느려도 다음 요청이 겹치지 않아요.
    await tester.pump(const Duration(seconds: 30));
    expect(repository.calls, hasLength(2));
    final clock = FixtureClock(
      periodTypeId: 2,
      countsFrom: 45,
      minutes: 65,
      seconds: 31,
      ticking: true,
      isStale: false,
      sampleAgeSeconds: 0,
      receivedAt: time.clock.now(),
    );
    repository.calls.last.complete(
        _detail(status: FixtureStatus.live, stateId: 22, clock: clock));
    await tester.pump();
    await tester.pump();
    expect(find.text('MATCH INFO'), findsOneWidget);
    expect(find.text('65:31'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    repository.calls.last.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Unable to load match.'), findsNothing);
    expect(find.byType(MatchScoreHeader), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    expect(repository.calls, hasLength(4));
    repository.calls.last.complete(
        _detail(status: FixtureStatus.live, stateId: 3, clock: clock));
    await tester.pump();
    await tester.pump();
    expect(find.text('Half Time'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(repository.calls, hasLength(4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(repository.calls, hasLength(5));
    repository.calls.last.complete(_detail(stateId: 5, clock: clock));
    await tester.pump();
    await tester.pump();
    expect(find.text('Full Time'), findsOneWidget);
    expect(find.text('ANALYSIS'), findsOneWidget);
    expect(find.text('LIVE CHAT'), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(repository.calls, hasLength(5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loads a fixture detail asynchronously on a compact screen',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'upcoming',
          repository: repository,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('match-loading-indicator')),
      findsOneWidget,
    );
    expect(repository.calls, hasLength(1));

    repository.calls.single.complete(_detail(status: FixtureStatus.upcoming));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries when fixture detail loading fails on a tall screen',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'upcoming',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Unable to load match.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('match-retry-button')));
    await tester.pump();
    expect(repository.calls, hasLength(2));

    repository.calls.last.complete(_detail(status: FixtureStatus.upcoming));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an invalid fixture ID without calling the repository',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: 'not-a-number',
          matchStatus: 'upcoming',
          repository: repository,
        ),
      ),
    );

    expect(find.text('Match not found'), findsOneWidget);
    expect(repository.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry state when route fixture detail is unavailable',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'upcoming',
          initialFixture: _fixture,
          repository: repository,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('match-loading-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );

    repository.calls.single.completeError(StateError('no mock detail'));
    await tester.pump();

    expect(find.text('Unable to load match.'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-betting-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes the loaded fixture detail to Match Info', (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();
    final detail = _detail(
      venueName: 'Test Stadium',
      expectedGoals: const FixtureExpectedGoals(
        homeXg: 0.518846,
        awayXg: 4.76916,
        homeXga: 4.76916,
        awayXga: 0.518846,
        provider: 'understat',
      ),
      coaches: [
        FixtureCoach(
          teamId: _fixture.awayTeamId,
          coachId: 902,
          name: 'Away Coach',
        ),
        FixtureCoach(
          teamId: _fixture.homeTeamId,
          coachId: 901,
          name: 'Home Coach',
        ),
      ],
      statistics: [
        FixtureStatistic(
          teamId: _fixture.awayTeamId,
          statTypeId: 45,
          statCode: 'ball-possession',
          statName: 'Ball Possession',
          value: 36.4,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 45,
          statCode: 'ball-possession',
          statName: 'Ball Possession',
          value: 63.6,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 42,
          statCode: 'shots-total',
          statName: 'Shots Total',
          value: 10,
        ),
        FixtureStatistic(
          teamId: _fixture.awayTeamId,
          statTypeId: 42,
          statCode: 'shots-total',
          statName: 'Shots Total',
          value: 6,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 84,
          statCode: 'yellowcards',
          statName: 'Yellow Cards',
          value: 2,
        ),
      ],
      events: _matchEvents,
      lineups: _lineups,
      formations: [
        FixtureFormation(
          teamId: _fixture.homeTeamId,
          formation: '4-3-3',
        ),
        FixtureFormation(
          teamId: _fixture.awayTeamId,
          formation: '4-2-3-1',
        ),
      ],
      pressure: [
        FixturePressurePoint(
          teamId: _fixture.homeTeamId,
          minute: 10,
          pressure: 0.7,
        ),
        FixturePressurePoint(
          teamId: _fixture.awayTeamId,
          minute: 20,
          pressure: 0.4,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'past',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.complete(detail);
    await tester.pump();

    final matchInfo = tester.widget<MatchInfoTab>(find.byType(MatchInfoTab));
    final coaches = tester.widget<SubstitutesAndCoach>(
      find.byType(SubstitutesAndCoach),
    );
    final statistics = tester.widget<StatBarsSection>(
      find.byType(StatBarsSection),
    );
    expect(find.byType(MatchScoreHeader), findsOneWidget);
    final events = tester.widget<MatchEventsSection>(
      find.byType(MatchEventsSection),
    );
    final momentum = tester.widget<MomentumChart>(
      find.byType(MomentumChart),
    );
    final lineup = tester.widget<LineupPitch>(find.byType(LineupPitch));
    final possession = statistics.bars.singleWhere(
      (bar) => bar.category == 'Ball Possession',
    );
    final yellowCards = statistics.bars.singleWhere(
      (bar) => bar.category == 'Yellow Cards',
    );
    expect(matchInfo.detail, same(detail));
    expect(matchInfo.fixture, same(detail.fixture));
    expect(
      tester.widget<MatchHighlights>(find.byType(MatchHighlights)).fixtureId,
      detail.fixture.fixtureId,
    );
    expect(coaches.coachA, 'Home Coach');
    expect(coaches.coachB, 'Away Coach');
    expect(find.text('Test Stadium'), findsNothing);
    expect(find.text('Full Time'), findsOneWidget);
    expect(
      events.events.any(
        (event) =>
            event.player == 'Home Starter' &&
            event.minute == "45+2'" &&
            event.side == MatchEventSide.home &&
            event.type == MatchSummaryEventType.goal,
      ),
      isTrue,
    );
    expect(
      events.events.any(
        (event) =>
            event.player == 'Away Defender' &&
            event.minute == "70'" &&
            event.side == MatchEventSide.away &&
            event.type == MatchSummaryEventType.redCard,
      ),
      isTrue,
    );
    expect(possession.homePercent, 63.6);
    expect(possession.awayPercent, 36.4);
    expect(possession.isPercent, isTrue);
    expect(statistics.bars.map((bar) => bar.category), [
      'Ball Possession',
      'Shots',
      'Yellow Cards',
    ]);
    expect(yellowCards.homePercent, 2);
    expect(yellowCards.awayPercent, 0);
    expect(statistics.homeColor, const Color(0xFFD92455));
    expect(statistics.awayColor, const Color(0xFF18539F));
    expect(momentum.homeColor, const Color(0xFFD92455));
    expect(momentum.awayColor, const Color(0xFF18539F));
    expect(momentum.animate, isTrue);
    expect(
      tester
          .widget<Container>(
            find.byKey(
              const ValueKey('match-info-stat-Ball Possession-home-fill'),
            ),
          )
          .color,
      statistics.homeColor,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(
              const ValueKey('match-info-stat-Ball Possession-away-fill'),
            ),
          )
          .color,
      statistics.awayColor,
    );
    expect(momentum.values[10], 0.7);
    expect(momentum.values[20], -0.4);
    expect(lineup.homeColor, const Color(0xFFD92455));
    expect(lineup.awayColor, const Color(0xFF18539F));
    _expectLineupPlayerColors(
      tester,
      playerFinder: find.byKey(
        ValueKey('match-lineup-player-${_fixture.homeTeamId}-101'),
      ),
      circleColor: lineup.homeColor,
    );
    _expectLineupPlayerColors(
      tester,
      playerFinder: find.byKey(
        ValueKey('match-lineup-player-${_fixture.awayTeamId}-200'),
      ),
      circleColor: lineup.awayColor,
    );
    expect(lineup.homeRows.first.single.name, 'Home Starter');
    expect(
      lineup.homeRows.first.single.events.map((event) => event.type),
      containsAll([LineupEventType.goal, LineupEventType.subOut]),
    );
    expect(lineup.homeRows.last.single.name, 'Home Keeper');
    expect(lineup.awayRows.first.single.name, 'Away Keeper');
    expect(
      lineup.awayRows[1].single.events.map((event) => event.type),
      contains(LineupEventType.redCard),
    );
    expect(coaches.subsA.single.name, 'Home Substitute');
    expect(coaches.subsA.single.minute, 80);
    expect(coaches.subsA.single.subIn, isTrue);
    expect(coaches.subsB.single.name, 'Away Substitute');
    expect(coaches.subsB.single.minute, 75);
    expect(find.byKey(const ValueKey('match-player-of-the-match-card')),
        findsNothing);
    expect(find.text('0.52'), findsNothing);
    expect(find.text('4.77'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (size, formation) in [
    for (final size in [const Size(320, 568), const Size(430, 932)])
      for (final formation in [null, '4-3-3']) (size, formation),
  ]) {
    testWidgets('orients both lineups toward midfield at $size ($formation)',
        (tester) async {
      await _setScreenSize(tester, size);
      // 공급자 좌표는 홈이 오른쪽부터, 원정이 왼쪽부터 시작해요.
      // https://docs.sportmonks.com/v3/tutorials-and-guides/tutorials/lineups-and-formations
      const positions = [
        (name: 'Keeper', row: 1, homeSlot: 1, awaySlot: 1),
        (name: 'Right Back', row: 2, homeSlot: 1, awaySlot: 4),
        (name: 'Right Centre Back', row: 2, homeSlot: 2, awaySlot: 3),
        (name: 'Left Centre Back', row: 2, homeSlot: 3, awaySlot: 2),
        (name: 'Left Back', row: 2, homeSlot: 4, awaySlot: 1),
        (name: 'Right Midfielder', row: 3, homeSlot: 1, awaySlot: 3),
        (name: 'Centre Midfielder', row: 3, homeSlot: 2, awaySlot: 2),
        (name: 'Left Midfielder', row: 3, homeSlot: 3, awaySlot: 1),
        (name: 'Right Winger', row: 4, homeSlot: 1, awaySlot: 3),
        (name: 'Striker', row: 4, homeSlot: 2, awaySlot: 2),
        (name: 'Left Winger', row: 4, homeSlot: 3, awaySlot: 1),
      ];
      final detail = _detail(
        formations: [
          if (formation != null)
            for (final teamId in [_fixture.homeTeamId, _fixture.awayTeamId])
              FixtureFormation(teamId: teamId, formation: formation),
        ],
        lineups: [
          for (final teamId in [_fixture.homeTeamId, _fixture.awayTeamId])
            for (final (index, position) in positions.indexed)
              _lineupEntry(
                teamId: teamId,
                playerId: index + 1,
                playerName: position.name,
                formationField: '${position.row}:'
                    '${teamId == _fixture.homeTeamId ? position.homeSlot : position.awaySlot}',
                jerseyNumber: index + 1,
              ),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: MatchInfoTab(fixture: detail.fixture, detail: detail),
        ),
      ));
      await tester.pumpAndSettle();

      final lineup = tester.widget<LineupPitch>(find.byType(LineupPitch));
      expect(lineup.homeRows.map((row) => row.length),
          formation == '4-3-3' ? [3, 2, 1, 4, 1] : [3, 3, 4, 1]);
      expect(lineup.awayRows.map((row) => row.length),
          formation == '4-3-3' ? [1, 4, 1, 2, 3] : [1, 4, 3, 3]);
      final pitch = tester.getRect(
        find.byKey(const ValueKey('match-lineup-card')),
      );
      final rows = <List<Rect>>[];
      for (final teamId in [_fixture.homeTeamId, _fixture.awayTeamId]) {
        final players = [
          for (var id = 1; id <= positions.length; id++)
            tester.getRect(find.byKey(
              ValueKey('match-lineup-player-$teamId-$id'),
            )),
        ];
        rows.add(players);
        for (final player in players) {
          expect(player.left, greaterThanOrEqualTo(pitch.left));
          expect(player.right, lessThanOrEqualTo(pitch.right));
          expect(player.top, greaterThanOrEqualTo(pitch.top));
          expect(player.bottom, lessThanOrEqualTo(pitch.bottom));
        }
        // 골키퍼가 아래인 홈은 왼쪽 선수가 화면 왼쪽, 위인 원정은 반대예요.
        final isHome = teamId == _fixture.homeTeamId;
        if (formation == '4-3-3') {
          // 중앙 공격수는 윙어보다 앞에, 풀백은 센터백보다 앞에 있어야 해요.
          for (final (front, back) in [(9, 8), (9, 10), (1, 2), (4, 3)]) {
            expect(
                players[front].top,
                isHome
                    ? lessThan(players[back].top)
                    : greaterThan(players[back].top));
          }
          for (var i = 0; i < players.length; i++) {
            for (var j = i + 1; j < players.length; j++) {
              expect(players[i].overlaps(players[j]), isFalse,
                  reason: 'players $i and $j must fit their names');
            }
          }
          // 중앙 미드필더만 골키퍼 쪽으로 내려가고, 양옆 선수는 같은 줄에 있어야 해요.
          expect(players[5].top, players[7].top);
          expect(players[6].center.dx, closeTo(players[0].center.dx, 0.001));
          expect(
              players[6].top,
              isHome
                  ? greaterThan(players[5].bottom)
                  : lessThan(players[5].top));
        } else {
          expect(players[5].top, players[6].top);
          expect(players[6].top, players[7].top);
        }
        for (final (right, left) in [(1, 4), (5, 7), (8, 10)]) {
          expect(
            players[left].center.dx,
            isHome
                ? lessThan(players[right].center.dx)
                : greaterThan(players[right].center.dx),
          );
        }
        for (final (back, front) in [(0, 1), (1, 5), (5, 8)]) {
          expect(
            players[back].center.dy,
            isHome
                ? greaterThan(players[front].center.dy)
                : lessThan(players[front].center.dy),
          );
        }
      }
      expect(rows.last[9].bottom, lessThan(rows.first[9].top));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final formation in ['4-3-3', '4-1-2-3', '4-2-3-1', '3-4-3']) {
      testWidgets('shares all Best Eleven coordinates in $formation at $size',
          (tester) async {
        await _setScreenSize(tester, size);
        final rowWidths = [1, ...formation.split('-').map(int.parse)];
        final slots = [
          for (var row = 0; row < rowWidths.length; row++)
            for (var column = 1; column <= rowWidths[row]; column++)
              '${row + 1}:$column',
        ];
        String reverseSlot(String slot) {
          final parts = slot.split(':').map(int.parse).toList();
          return '${parts[0]}:${rowWidths[parts[0] - 1] + 1 - parts[1]}';
        }

        Offset relativeCenter(Finder finder, Rect area) {
          final center = tester.getCenter(finder) - area.topLeft;
          return Offset(center.dx / area.width, center.dy / area.height);
        }

        await tester.pumpWidget(MaterialApp(
          theme: app_style.darktheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BestElevenPitch(
                teamId: _fixture.homeTeamId,
                formation: formation,
                players: [
                  for (final (index, slot) in slots.indexed)
                    BestElevenEntry(
                      slotKey: slot,
                      slotIndex: index,
                      playerId: index + 1,
                      playerName: 'Player $index',
                      starts: 1,
                      jerseyNumber: index + 1,
                    ),
                ],
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final bestPitch = tester.getRect(
          find.byKey(const ValueKey('team-best-eleven-card')),
        );
        final bestPositions = {
          for (final slot in slots)
            slot: relativeCenter(
              find.byKey(ValueKey('best-eleven-player-dot-$slot')),
              bestPitch,
            ),
        };
        expect(tester.takeException(), isNull);

        final detail = _detail(
          formations: [
            for (final teamId in [_fixture.homeTeamId, _fixture.awayTeamId])
              FixtureFormation(teamId: teamId, formation: formation),
          ],
          lineups: [
            for (final teamId in [_fixture.homeTeamId, _fixture.awayTeamId])
              for (final (index, slot) in slots.indexed)
                _lineupEntry(
                  teamId: teamId,
                  playerId: index + 1,
                  playerName: 'Player $index',
                  formationField:
                      teamId == _fixture.homeTeamId ? reverseSlot(slot) : slot,
                  jerseyNumber: index + 1,
                ),
          ],
        );
        await tester.pumpWidget(MaterialApp(
          theme: app_style.darktheme,
          home: Scaffold(
            body: MatchInfoTab(fixture: detail.fixture, detail: detail),
          ),
        ));
        await tester.pumpAndSettle();
        final halves = find.byType(FormationPlayerPositions<LineupPlayer>);
        expect(halves, findsNWidgets(2));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('match-lineup-card')))
              .height,
          820,
        );
        for (final isHome in [true, false]) {
          final teamId = isHome ? _fixture.homeTeamId : _fixture.awayTeamId;
          final half = tester.getRect(isHome ? halves.last : halves.first);
          for (final (index, slot) in slots.indexed) {
            final circle = find.descendant(
              of: find
                  .byKey(ValueKey('match-lineup-player-$teamId-${index + 1}')),
              matching: find.byKey(const ValueKey('lineup-player-circle')),
            );
            final actual = relativeCenter(circle, half);
            final expected = bestPositions[isHome ? slot : reverseSlot(slot)]!;
            expect(actual.dx, closeTo(expected.dx, 0.000001),
                reason: '$teamId $slot x');
            expect(actual.dy,
                closeTo(isHome ? expected.dy : 1 - expected.dy, 0.000001),
                reason: '$teamId $slot y');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('opens player match statistics from a past-match lineup',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final detail = _detail(
      lineups: _lineups,
      playerStatistics: [_homeStarterStatistics],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: MatchInfoTab(
            fixture: detail.fixture,
            detail: detail,
          ),
        ),
      ),
    );
    await tester.pump();

    final player = find.byKey(
      ValueKey(
        'match-lineup-player-${_fixture.homeTeamId}-101',
      ),
    );
    await tester.ensureVisible(player);
    await tester.pumpAndSettle();
    await tester.tap(player);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player-match-stat-sheet')),
      findsOneWidget,
    );
    final statHeader = tester.widget<Container>(
      find.byKey(const ValueKey('player-match-stat-header')),
    );
    final headerGradient =
        (statHeader.decoration as BoxDecoration).gradient as LinearGradient;
    const teamPrimary = Color(0xFFD92455);
    expect(headerGradient.colors, [
      teamPrimary,
      Color.alphaBlend(
        Colors.black.withValues(alpha: 0.28),
        teamPrimary,
      ),
      Color.alphaBlend(
        Colors.black.withValues(alpha: 0.62),
        teamPrimary,
      ),
    ]);
    for (final color in headerGradient.colors) {
      expect(
        ColorUtils.getContrastRatio(color, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(find.text('Home Starter'), findsWidgets);
    expect(find.text('FINISH'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('xG'), findsOneWidget);
    expect(find.text('0.52'), findsOneWidget);
    expect(find.text('Unavailable metric'), findsNothing);
    expect(
      tester
          .widget<GestureDetector>(
            find.byKey(
              const ValueKey('player-match-stat-profile-link'),
            ),
          )
          .onTap,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens player match statistics from a substitute row',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final detail = _detail(
      lineups: _lineups,
      events: _matchEvents,
      playerStatistics: [_homeSubstituteStatistics],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: MatchInfoTab(
            fixture: detail.fixture,
            detail: detail,
          ),
        ),
      ),
    );
    await tester.pump();

    final substitute = find.byKey(
      ValueKey(
        'match-substitute-player-${_fixture.homeTeamId}-104',
      ),
    );
    await tester.ensureVisible(substitute);
    await tester.pumpAndSettle();
    await tester.tap(substitute);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player-match-stat-sheet')),
      findsOneWidget,
    );
    expect(find.text('Home Substitute'), findsWidgets);
    expect(find.text('PASSING'), findsOneWidget);
    expect(find.text('Accurate Passes'), findsOneWidget);
    expect(find.text('12 / 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps all live statistics in order when zero or omitted',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();
    const labels = [
      '점유율',
      '패스',
      '패스 성공률',
      '슈팅',
      '유효 슈팅',
      '코너킥',
      '오프사이드',
      '선방',
      '파울',
      '경고',
      '퇴장',
    ];

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: MatchScreen(
        matchId: '${_fixture.fixtureId}',
        matchStatus: 'live',
        repository: repository,
      ),
    ));
    expect(find.byType(StatBarsSection), findsNothing);

    repository.calls.single.complete(_detail(status: FixtureStatus.live));
    await tester.pump();
    await tester.pump();

    void expectOrderedRows() {
      final rows = find.byType(StatComparisonBar);
      expect(rows, findsNWidgets(labels.length));
      for (var index = 0; index < labels.length; index++) {
        expect(
          find.descendant(
              of: rows.at(index), matching: find.text(labels[index])),
          findsOneWidget,
        );
      }
    }

    expectOrderedRows();
    for (final row in tester.widgetList<StatComparisonBar>(
      find.byType(StatComparisonBar),
    )) {
      expect(row.data.homePercent, 0);
      expect(row.data.awayPercent, 0);
      expect(
        find.descendant(
          of: find.byWidget(row),
          matching: find.text(row.data.isPercent ? '0%' : '0'),
        ),
        findsNWidgets(2),
      );
    }

    await tester.pump(const Duration(seconds: 15));
    repository.calls.last.complete(_detail(
      status: FixtureStatus.live,
      statistics: [
        FixtureStatistic(
          teamId: _fixture.awayTeamId,
          statTypeId: 80,
          statCode: 'passes',
          statName: 'Passes',
          value: 232,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 84,
          statCode: 'yellowcards',
          statName: 'Yellow Cards',
          value: 1,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 80,
          statCode: 'passes',
          statName: 'Passes',
          value: 224,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 83,
          statCode: 'redcards',
          statName: 'Redcards',
          value: 0,
        ),
        FixtureStatistic(
          teamId: _fixture.awayTeamId,
          statTypeId: 83,
          statCode: 'redcards',
          statName: 'Redcards',
          value: 0,
        ),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expectOrderedRows();
    final bars =
        tester.widget<StatBarsSection>(find.byType(StatBarsSection)).bars;
    final passes = bars.singleWhere((bar) => bar.category == 'Passes');
    expect(passes.homePercent, 224);
    expect(passes.awayPercent, 232);
    expect(passes.isPercent, isFalse);
    final yellowCards =
        bars.singleWhere((bar) => bar.category == 'Yellow Cards');
    expect(yellowCards.homePercent, 1);
    expect(yellowCards.awayPercent, 0);
    final redCards = bars.singleWhere((bar) => bar.category == 'Red Cards');
    expect(redCards.homePercent, 0);
    expect(redCards.awayPercent, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('uses neutral labels and omits incomplete detail statistics',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'past',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.complete(
      _detail(
        statistics: [
          FixtureStatistic(
            teamId: _fixture.homeTeamId,
            statTypeId: 45,
            statCode: 'ball-possession',
            statName: 'Ball Possession',
            value: 63.6,
          ),
        ],
      ),
    );
    await tester.pump();

    final coaches = tester.widget<SubstitutesAndCoach>(
      find.byType(SubstitutesAndCoach),
    );
    expect(coaches.coachA, '—');
    expect(coaches.coachB, '—');
    expect(find.byType(StatBarsSection), findsNothing);
    expect(find.byType(MatchEventsSection), findsNothing);
    expect(find.byType(MomentumChart), findsNothing);
    expect(find.byType(LineupPitch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes loaded expected goals and events to Analysis',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();
    final detail = _detail(
      expectedGoals: const FixtureExpectedGoals(
        homeXg: 1.234,
        awayXg: 0.567,
        homeXga: 0.567,
        awayXga: 1.234,
        provider: 'understat',
      ),
      events: _matchEvents,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'past',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.complete(detail);
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('match-tab-scroll')),
      const Offset(-300, 0),
    );
    await tester.pump();
    await tester.tap(find.text('ANALYSIS'));
    await tester.pump();

    final analysis = tester.widget<AnalysisTab>(find.byType(AnalysisTab));
    final headerRect = tester.getRect(find.byType(MatchScoreHeader));
    final tabRect = tester.getRect(find.byKey(const ValueKey('match-tab-2')));
    expect(headerRect.top - tabRect.bottom, 24);
    expect(headerRect.left, 24);
    expect(headerRect.right, 430 - 24);
    final eventsRect = tester.getRect(find.byType(MatchEventsSection));
    final xgRect =
        tester.getRect(find.byKey(const ValueKey('match-analysis-xg')));
    expect(xgRect.top - eventsRect.bottom, 12);
    final events = tester.widget<MatchEventsSection>(
      find.byKey(const ValueKey('match-analysis-events')),
    );
    expect(analysis.detail, same(detail));
    expect(events.events, hasLength(2));
    expect(
      events.events.any(
        (event) =>
            event.player == 'Home Starter' &&
            event.minute == "45+2'" &&
            event.side == MatchEventSide.home &&
            event.type == MatchSummaryEventType.goal,
      ),
      isTrue,
    );
    expect(
      events.events.any(
        (event) =>
            event.player == 'Away Defender' &&
            event.minute == "70'" &&
            event.side == MatchEventSide.away &&
            event.type == MatchSummaryEventType.redCard,
      ),
      isTrue,
    );
    expect(find.text('Lewandowski'), findsNothing);
    expect(find.byKey(const ValueKey('match-analysis-xg')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('match-analysis-xg')),
        matching: find.text('1.23'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('match-analysis-xg')),
        matching: find.text('0.57'),
      ),
      findsOneWidget,
    );
    for (final (key, team, value) in [
      (
        'match-analysis-home-xg-box',
        fixtureHomeTeam(_fixture, teamRepository),
        '1.23',
      ),
      (
        'match-analysis-away-xg-box',
        fixtureAwayTeam(_fixture, teamRepository),
        '0.57',
      ),
    ]) {
      final box = find.byKey(ValueKey(key));
      final decoration =
          tester.widget<Container>(box).decoration! as ShapeDecoration;
      final primary = TeamComparisonColorResolver.paletteFor(
        teamName: team.name,
        primaryFallback: Color(team.primaryColor),
      ).primary;
      final text = tester.widget<Text>(find.descendant(
        of: box,
        matching: find.text(value),
      ));
      final foreground = text.style!.color!;
      expect(decoration.color, primary);
      expect(foreground, anyOf(Colors.black, Colors.white));
      expect(ColorUtils.getContrastRatio(primary, foreground),
          greaterThanOrEqualTo(4.5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits unavailable Analysis detail sections', (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'past',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.complete(_detail());
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('match-tab-scroll')),
      const Offset(-300, 0),
    );
    await tester.pump();
    await tester.tap(find.text('ANALYSIS'));
    await tester.pump();

    expect(find.byKey(const ValueKey('match-analysis-xg')), findsNothing);
    expect(find.byKey(const ValueKey('match-analysis-events')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _expectLineupPlayerColors(
  WidgetTester tester, {
  required Finder playerFinder,
  required Color circleColor,
}) {
  final circleFinder = find.descendant(
    of: playerFinder,
    matching: find.byKey(const ValueKey('lineup-player-circle')),
  );
  final circle = tester.widget<Container>(circleFinder);
  expect((circle.decoration! as BoxDecoration).color, circleColor);

  final jerseyNumber = tester.widget<Text>(
    find.descendant(of: circleFinder, matching: find.byType(Text)),
  );
  final jerseyColor = jerseyNumber.style!.color!;
  expect(
    ColorUtils.getContrastRatio(circleColor, jerseyColor),
    greaterThanOrEqualTo(4.5),
  );
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final Fixture _fixture = mockFixtures.firstWhere(
  (fixture) => fixture.fixtureId == 20100001,
);

FixtureDetail _detail({
  FixtureStatus status = FixtureStatus.past,
  int? stateId,
  FixtureClock? clock,
  String? venueName,
  FixtureExpectedGoals? expectedGoals,
  List<FixtureCoach> coaches = const [],
  List<FixtureStatistic> statistics = const [],
  List<FixturePlayerStatistic> playerStatistics = const [],
  List<FixtureEvent> events = const [],
  List<FixtureLineupEntry> lineups = const [],
  List<FixtureFormation> formations = const [],
  List<FixturePressurePoint> pressure = const [],
}) {
  return FixtureDetail(
    fixture: Fixture(
      fixtureId: _fixture.fixtureId,
      seasonId: _fixture.seasonId,
      competitionId: _fixture.competitionId,
      homeTeamId: _fixture.homeTeamId,
      awayTeamId: _fixture.awayTeamId,
      competitionType: _fixture.competitionType,
      roundName: _fixture.roundName,
      legNumber: _fixture.legNumber,
      status: status,
      stateId: stateId,
      startingAt: _fixture.startingAt,
    ),
    venueName: venueName,
    clock: clock,
    expectedGoals: expectedGoals,
    playerExpectedGoals: const [],
    shots: const [],
    events: events,
    statistics: statistics,
    playerStatistics: playerStatistics,
    lineups: lineups,
    formations: formations,
    coaches: coaches,
    pressure: pressure,
  );
}

final FixturePlayerStatistic _homeStarterStatistics = FixturePlayerStatistic(
  teamId: _fixture.homeTeamId,
  playerId: 101,
  matchPositionId: 27,
  positionGroup: 'FW',
  minutesPlayed: 90,
  rating: 8.4,
  isManOfMatch: false,
  categories: [
    FixturePlayerStatCategory(
      code: 'finish',
      label: 'Finish',
      metrics: [
        FixturePlayerStatMetric(
          code: 'goals',
          label: 'Goals',
          kind: 'count',
          source: 'sportmonks',
          statTypeIds: [52],
          value: 1,
          numerator: null,
          denominator: null,
        ),
        FixturePlayerStatMetric(
          code: 'xg',
          label: 'xG',
          kind: 'decimal',
          source: 'understat',
          statTypeIds: const [],
          value: 0.518846,
          numerator: null,
          denominator: null,
        ),
        FixturePlayerStatMetric(
          code: 'unavailable',
          label: 'Unavailable metric',
          kind: 'count',
          source: 'sportmonks',
          statTypeIds: const [],
          value: null,
          numerator: null,
          denominator: null,
        ),
      ],
    ),
  ],
);

final FixturePlayerStatistic _homeSubstituteStatistics = FixturePlayerStatistic(
  teamId: _fixture.homeTeamId,
  playerId: 104,
  matchPositionId: 27,
  positionGroup: 'FW',
  minutesPlayed: 10,
  rating: 6.7,
  isManOfMatch: false,
  categories: [
    FixturePlayerStatCategory(
      code: 'passing',
      label: 'Passing',
      metrics: [
        FixturePlayerStatMetric(
          code: 'accurate-passes',
          label: 'Accurate passes',
          kind: 'pair',
          source: 'sportmonks',
          statTypeIds: const [80, 81],
          value: null,
          numerator: 12,
          denominator: 15,
        ),
      ],
    ),
  ],
);

final List<FixtureEvent> _matchEvents = [
  FixtureEvent(
    eventId: 1,
    teamId: _fixture.homeTeamId,
    eventTypeId: 14,
    eventTypeCode: 'goal',
    eventTypeName: 'Goal',
    playerId: 101,
    playerName: 'Home Starter',
    playerImage: null,
    relatedPlayerId: 102,
    relatedPlayerName: 'Home Keeper',
    relatedPlayerImage: null,
    minute: 45,
    extraMinute: 2,
    onBench: false,
  ),
  FixtureEvent(
    eventId: 2,
    teamId: _fixture.awayTeamId,
    eventTypeId: 20,
    eventTypeCode: 'redcard',
    eventTypeName: 'Red Card',
    playerId: 201,
    playerName: 'Away Defender',
    playerImage: null,
    relatedPlayerId: null,
    relatedPlayerName: null,
    relatedPlayerImage: null,
    minute: 70,
    extraMinute: null,
    onBench: false,
  ),
  FixtureEvent(
    eventId: 3,
    teamId: _fixture.awayTeamId,
    eventTypeId: 18,
    eventTypeCode: 'substitution',
    eventTypeName: 'Substitution',
    playerId: 202,
    playerName: 'Away Substitute',
    playerImage: null,
    relatedPlayerId: 203,
    relatedPlayerName: 'Away Starter',
    relatedPlayerImage: null,
    minute: 75,
    extraMinute: null,
    onBench: true,
  ),
  FixtureEvent(
    eventId: 4,
    teamId: _fixture.homeTeamId,
    eventTypeId: 18,
    eventTypeCode: 'substitution',
    eventTypeName: 'Substitution',
    playerId: 104,
    playerName: 'Home Substitute',
    playerImage: null,
    relatedPlayerId: 101,
    relatedPlayerName: 'Home Starter',
    relatedPlayerImage: null,
    minute: 80,
    extraMinute: null,
    onBench: true,
  ),
];

final List<FixtureLineupEntry> _lineups = [
  _lineupEntry(
    teamId: _fixture.homeTeamId,
    playerId: 102,
    playerName: 'Home Keeper',
    formationField: '1:1',
    jerseyNumber: 1,
  ),
  _lineupEntry(
    teamId: _fixture.homeTeamId,
    playerId: 101,
    playerName: 'Home Starter',
    formationField: '4:1',
    jerseyNumber: 9,
  ),
  _lineupEntry(
    teamId: _fixture.homeTeamId,
    playerId: 104,
    playerName: 'Home Substitute',
    formationField: null,
    jerseyNumber: 14,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 200,
    playerName: 'Away Keeper',
    formationField: '1:1',
    jerseyNumber: 1,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 201,
    playerName: 'Away Defender',
    formationField: '2:1',
    jerseyNumber: 4,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 203,
    playerName: 'Away Starter',
    formationField: '4:1',
    jerseyNumber: 9,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 202,
    playerName: 'Away Substitute',
    formationField: null,
    jerseyNumber: 12,
  ),
];

FixtureLineupEntry _lineupEntry({
  required int teamId,
  required int playerId,
  required String playerName,
  required String? formationField,
  required int jerseyNumber,
}) {
  return FixtureLineupEntry(
    teamId: teamId,
    playerId: playerId,
    playerName: playerName,
    playerImage: null,
    positionId: null,
    lineupTypeId: formationField == null ? 12 : 11,
    formationField: formationField,
    jerseyNumber: jerseyNumber,
    minutesPlayed: null,
    rating: null,
  );
}

class _ControlledFixtureRepository extends MockFixtureRepository {
  _ControlledFixtureRepository() : super(fixtures: const []);

  final List<Completer<FixtureDetail>> calls = [];

  @override
  Future<FixtureDetail> loadDetail(int fixtureId) {
    final completer = Completer<FixtureDetail>();
    calls.add(completer);
    return completer.future;
  }
}
