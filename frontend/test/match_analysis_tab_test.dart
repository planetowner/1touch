import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/l10n/app_localizations.dart';
import 'support/test_match_analysis_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';
import 'package:onetouch/features/match_info/match_motion.dart';
import 'package:onetouch/screens/MatchScreen_tabs/Anal.dart';

void main() {
  setUpAppCatalog();
  test('shot-map dots lead lines, and arrows stagger by 420ms', () {
    expect(matchShotTimelineMs, 503);
    expect(matchShotTimelineDurationMs(1), 503);
    expect(matchShotTimelineDurationMs(3), 669);
    expect(matchProgressionTimelineMs, 1673);

    double shotProgress(int elapsedMs, int shotIndex, {bool line = false}) =>
        matchMotionSegmentProgress(
          elapsedMs / matchShotTimelineDurationMs(3),
          totalMs: matchShotTimelineDurationMs(3),
          startMs: shotIndex * matchShotStaggerMs +
              (line ? matchShotLineDelayMs : 0),
          durationMs: matchShotCircleDurationMs,
        );

    expect(shotProgress(82, 0), greaterThan(0));
    expect(shotProgress(82, 0, line: true), 0);
    expect(shotProgress(82, 1), 0);
    expect(shotProgress(100, 0, line: true), greaterThan(0));
    expect(shotProgress(100, 1), greaterThan(0));
    expect(shotProgress(165, 2), 0);
    expect(shotProgress(420, 0), 1);
    expect(shotProgress(503, 0, line: true), 1);
    expect(shotProgress(669, 2, line: true), 1);

    double arrowProgress(int elapsedMs, int arrowIndex) =>
        matchMotionSegmentProgress(
          elapsedMs / matchProgressionTimelineMs,
          totalMs: matchProgressionTimelineMs,
          startMs: arrowIndex * matchArrowStaggerMs,
          durationMs: matchMotionDurationMs,
        );

    expect(arrowProgress(419, 1), 0);
    expect(arrowProgress(600, 1), greaterThan(0));
    expect(arrowProgress(600, 2), 0);
    expect(arrowProgress(833, 0), 1);
    expect(arrowProgress(1673, 2), 1);
  });

  testWidgets('attack reveals shots by match minute and preserves tied order',
      (tester) async {
    final fixture = mockFixtures.first;
    MatchShot shot(String id, int minute, int? extraMinute, double y) =>
        MatchShot(
          eventId: id,
          teamId: fixture.homeTeamId,
          playerId: null,
          playerName: null,
          minute: minute,
          extraMinute: extraMinute,
          result: 'missed',
          start: TacticalPitchPoint(x: 80, y: y),
          end: const TacticalPitchPoint(x: 100, y: 50),
        );
    final repository = TestMatchAnalysisRepository(
      MatchTacticalAnalysis(
        fixtureId: fixture.fixtureId,
        available: false,
        home: null,
        away: null,
      ),
      MatchShotMap(
        fixtureId: fixture.fixtureId,
        available: true,
        homeCount: 5,
        awayCount: 0,
        shots: [
          shot('45-plus-2-first', 45, 2, 40),
          shot('10', 10, null, 10),
          shot('45-plus-2-second', 45, 2, 50),
          shot('20', 20, null, 20),
          shot('45', 45, null, 30),
        ],
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home:
          Scaffold(body: AnalysisTab(fixture: fixture, repository: repository)),
    ));
    await tester.pumpAndSettle();

    final plots =
        tester.widget<ShotMapDiagram>(find.byType(ShotMapDiagram)).shots;
    expect(plots.map((plot) => plot.start.dx), [0.1, 0.2, 0.3, 0.4, 0.5]);
    final attackHelp = find.byKey(const ValueKey('match-analysis-attack-info'));
    expect(attackHelp, findsOneWidget);
    expect(tester.getSize(attackHelp), const Size(14, 14));
    expect(
        tester.getTopLeft(attackHelp).dx -
            tester.getTopRight(find.text('ATTACK')).dx,
        4);
    await tester.ensureVisible(attackHelp);
    await tester.tap(attackHelp);
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Shotmap showing where each shot on target was taken, with lines pointing to where it was aimed.'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-info-popup')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in appSupportedLocales) {
    testWidgets('possession uses a bar without a team toggle in $locale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = mockFixtures.first;
      final repository = TestMatchAnalysisRepository(
        MatchTacticalAnalysis(
          fixtureId: fixture.fixtureId,
          available: false,
          home: null,
          away: null,
        ),
        MatchShotMap(
          fixtureId: fixture.fixtureId,
          available: false,
          homeCount: null,
          awayCount: null,
          shots: const [],
        ),
      );
      final detail = _detailWithStatistics(fixture, [
        _stat(fixture.homeTeamId, 'ball-possession', 40),
        _stat(fixture.awayTeamId, 'ball-possession', 60),
        _stat(fixture.homeTeamId, 'successful-passes-percentage', 87),
        _stat(fixture.awayTeamId, 'successful-passes-percentage', 90),
        _stat(fixture.homeTeamId, 'touches', 551),
        _stat(fixture.awayTeamId, 'touches', 725),
      ]);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darktheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnalysisTab(
              fixture: fixture,
              detail: detail,
              repository: repository,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('match-analysis-possession-card'));
      final bar = find.byKey(const ValueKey('match-possession-bar'));
      expect(find.descendant(of: card, matching: find.byType(GestureDetector)),
          findsNothing);
      expect(
          find.text(translateMessage(locale, 'Ball Possession')), findsNothing);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(
          find.text(translateMessage(locale, 'Pass Accuracy')), findsOneWidget);
      expect(find.text(translateMessage(locale, 'Touches')), findsOneWidget);
      expect(tester.getSize(bar), const Size(297, 32));
      expect(tester.getTopLeft(bar) - tester.getTopLeft(card),
          const Offset(24, 24));
      expect(
        tester
            .widget<Column>(find.byKey(
              const ValueKey('match-analysis-possession-stat-rows'),
            ))
            .spacing,
        8,
      );
      expect(
          tester
              .widget<FractionallySizedBox>(
                  find.byKey(const ValueKey('match-possession-home-fill')))
              .widthFactor,
          0.4);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders real tactical values without the former pressure mocks',
      (tester) async {
    final fixture = mockFixtures.first;
    final analysis = MatchTacticalAnalysis(
      fixtureId: fixture.fixtureId,
      available: true,
      home: _team(
        fixture.homeTeamId,
        keyPasses: 7,
        recoveries: 4,
        actions: const [
          TacticalPitchPoint(x: 10, y: 20),
          TacticalPitchPoint(x: 20, y: 70),
          TacticalPitchPoint(x: 50, y: 40),
          TacticalPitchPoint(x: 80, y: 60),
        ],
      ),
      away: _team(
        fixture.awayTeamId,
        keyPasses: 2,
        recoveries: 4,
        actions: const [
          TacticalPitchPoint(x: 10, y: 20),
          TacticalPitchPoint(x: 45, y: 40),
          TacticalPitchPoint(x: 55, y: 70),
          TacticalPitchPoint(x: 80, y: 60),
        ],
      ),
    );
    final shotMap = MatchShotMap(
      fixtureId: fixture.fixtureId,
      available: true,
      homeCount: 3,
      awayCount: 1,
      shots: [
        MatchShot(
          eventId: 'goal-1',
          teamId: fixture.homeTeamId,
          playerId: 9,
          playerName: 'Striker',
          minute: 22,
          extraMinute: null,
          result: 'goal',
          start: const TacticalPitchPoint(x: 82, y: 48),
          end: const TacticalPitchPoint(x: 100, y: 50),
        ),
      ],
    );
    final repository = TestMatchAnalysisRepository(analysis, shotMap);
    final detail = _detailWithStatistics(
      fixture,
      [
        FixtureStatistic(
          teamId: fixture.homeTeamId,
          statTypeId: 45,
          statCode: 'ball-possession',
          statName: 'Ball Possession',
          value: 61,
        ),
        FixtureStatistic(
          teamId: fixture.awayTeamId,
          statTypeId: 45,
          statCode: 'ball-possession',
          statName: 'Ball Possession',
          value: 39,
        ),
        _keyPasses(fixture.homeTeamId, 25),
        _keyPasses(fixture.awayTeamId, 4),
        _stat(fixture.homeTeamId, 'tackles-won', 10),
        _stat(fixture.awayTeamId, 'tackles-won', 6),
        _stat(fixture.homeTeamId, 'interceptions', 6),
        _stat(fixture.awayTeamId, 'interceptions', 2),
        _stat(fixture.homeTeamId, 'blocked-shots', 7),
        _stat(fixture.awayTeamId, 'blocked-shots', 3),
        _stat(fixture.homeTeamId, 'duels-won', 7),
        _stat(fixture.awayTeamId, 'duels-won', 3),
        _stat(fixture.homeTeamId, 'clearances', 7),
        _stat(fixture.awayTeamId, 'clearances', 3),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: AnalysisTab(
            fixture: fixture,
            detail: detail,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ShotMapDiagram), findsOneWidget);
    expect(find.byType(ProgressionDiagram), findsOneWidget);
    expect(
      tester.widget<ShotMapDiagram>(find.byType(ShotMapDiagram)).color,
      const Color(0xFF5FAFF1),
    );
    expect(
      tester.widget<ProgressionDiagram>(find.byType(ProgressionDiagram)).color,
      const Color(0xFF5FAFF1),
    );
    expect(find.byType(DefenseTerritoryDiagram), findsOneWidget);
    expect(
      tester
          .widget<DefenseTerritoryDiagram>(
            find.byType(DefenseTerritoryDiagram),
          )
          .zoneDeltas,
      [25, -25, 0],
    );
    expect(
      tester
          .widget<DefenseTerritoryDiagram>(
            find.byType(DefenseTerritoryDiagram),
          )
          .selectedTeamColor,
      tester.widget<ProgressionDiagram>(find.byType(ProgressionDiagram)).color,
    );
    expect(
      tester
          .widget<DefenseTerritoryDiagram>(
            find.byType(DefenseTerritoryDiagram),
          )
          .rightToLeft,
      isFalse,
    );
    expect(defenseTerritoryOpacity(-20.8), closeTo(0.292, 0.0001));
    expect(defenseTerritoryOpacity(23.4), closeTo(0.734, 0.0001));
    expect(defenseTerritoryOpacity(-2.7), closeTo(0.473, 0.0001));
    expect(
      [
        for (var i = 0; i < 3; i++)
          defenseTerritoryZoneReveal(0.5, i, rightToLeft: false)
      ],
      [1, 0.5, 0],
    );
    expect(
      [
        for (var i = 0; i < 3; i++)
          defenseTerritoryZoneReveal(0.5, i, rightToLeft: true)
      ],
      [0, 0.5, 1],
    );
    expect(
      [
        for (var i = 0; i < 3; i++)
          defenseTerritoryZoneReveal(1, i, rightToLeft: true)
      ],
      [1, 1, 1],
    );
    expect(shotMapMarkerRadius, 5);
    expect(defenseTerritoryArrowGradient.begin, Alignment.centerLeft);
    expect(defenseTerritoryArrowGradient.end, Alignment.centerRight);
    expect(
      defenseTerritoryArrowGradient.colors,
      const [Color(0x00FFFFFF), Color(0x7AFFFFFF)],
    );
    final arrowShaft = defenseTerritoryArrowShaftRect(
      const Size(334, 208.75),
    );
    expect(arrowShaft.width, 233);
    expect(arrowShaft.height,
        closeTo(208.75 * defenseTerritoryCenterCircleRadiusFraction, 1e-9));
    expect(arrowShaft.left, lessThan(334 / 3));
    expect(arrowShaft.right, greaterThan(334 * 2 / 3));
    expect(arrowShaft.top, 208.75 / 2);
    expect(
      arrowShaft.bottom,
      closeTo(
        208.75 / 2 + 208.75 * defenseTerritoryCenterCircleRadiusFraction,
        1e-9,
      ),
    );
    final arrowHeadTop = arrowShaft.center.dy - 208.75 * 0.18;
    final arrowHeadBottom = arrowShaft.center.dy + 208.75 * 0.18;
    expect(arrowShaft.center.dy - arrowHeadTop,
        closeTo(arrowHeadBottom - arrowShaft.center.dy, 1e-9));
    final alignedLabelTop = defenseTerritoryLabelTop(
      labelHeight: 24,
      arrowHeadTop: arrowHeadTop,
    );
    expect(alignedLabelTop + 24, arrowHeadTop - 8);

    final compactArrowShaft = defenseTerritoryArrowShaftRect(
      const Size(224, 140),
    );
    expect(compactArrowShaft.left, 8);
    expect(compactArrowShaft.right, greaterThan(224 * 2 / 3));
    expect(compactArrowShaft.top, 70);
    expect(compactArrowShaft.bottom,
        closeTo(70 + 140 * defenseTerritoryCenterCircleRadiusFraction, 1e-9));
    final compactArrowHeadTop = compactArrowShaft.center.dy - 140 * 0.18;
    final compactArrowHeadBottom = compactArrowShaft.center.dy + 140 * 0.18;
    expect(compactArrowShaft.center.dy - compactArrowHeadTop,
        closeTo(compactArrowHeadBottom - compactArrowShaft.center.dy, 1e-9));
    expect(find.text('DEFENSE'), findsOneWidget);
    expect(find.text('PRESSURE'), findsNothing);
    expect(find.text('Tackles Won'), findsOneWidget);
    expect(find.text('Interceptions'), findsOneWidget);
    expect(find.text('Blocks'), findsOneWidget);
    expect(find.text('Duels Won'), findsOneWidget);
    expect(find.text('Clearances'), findsOneWidget);
    expect(find.text('Error'), findsNothing);
    expect(find.text('Carries into Final Third'), findsNothing);
    expect(find.text('Key Passes'), findsOneWidget);
    expect(_keyPassRowText(tester), ['25', 'Key Passes', '4']);
    for (final section in [
      'attack',
      'progression',
      'defense',
    ]) {
      final statRows = tester.widget<Column>(
        find.byKey(ValueKey('match-analysis-$section-stat-rows')),
      );
      expect(statRows.spacing, 8, reason: section);
    }
    expect(find.text('Recoveries'), findsNothing);
    expect(find.text('Ball Possession'), findsNothing);
    expect(find.text('61%'), findsOneWidget);
    expect(find.text('39%'), findsOneWidget);
    final possessionFill = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('match-possession-home-fill')),
    );
    expect(possessionFill.widthFactor, 0.61);
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(const ValueKey('match-possession-home-fill')),
              matching: find.byType(ColoredBox),
            ),
          )
          .color,
      const Color(0xFF5FAFF1),
    );
    final homeToggle = tester.widget<Container>(
      find.byKey(const ValueKey('match-analysis-home-toggle')).first,
    );
    final awayToggle = tester.widget<Container>(
      find.byKey(const ValueKey('match-analysis-away-toggle')).first,
    );
    final awayPossessionFill = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('match-possession-away-fill')),
    );
    expect(
      (homeToggle.decoration as BoxDecoration).color,
      Colors.transparent,
    );
    expect(
      (awayToggle.decoration as BoxDecoration).color,
      Colors.transparent,
    );
    final teamToggleIndicator = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('match-analysis-team-toggle-indicator')).first,
    );
    final teamToggleTrack = tester.widget<Container>(
      find.byKey(const ValueKey('match-analysis-team-toggle')).first,
    );
    expect((teamToggleTrack.decoration as BoxDecoration).color,
        const Color(0xFFF4F4F4));
    expect(homeToggle.padding, const EdgeInsets.all(8));
    expect(awayToggle.padding, const EdgeInsets.all(8));
    expect(
      (teamToggleIndicator.decoration as BoxDecoration).color,
      app_style.AppPalette.lightModeDarkGrey,
    );
    expect(
      (teamToggleIndicator.decoration as BoxDecoration).border?.top.color,
      const Color(0xFFF4F4F4),
    );
    expect(
      (teamToggleIndicator.decoration as BoxDecoration).border?.top.width,
      2,
    );
    expect(
      awayPossessionFill.color,
      const Color(0xFFEF2C34),
    );

    await tester.tap(
      find.byKey(const ValueKey('match-analysis-away-toggle')).first,
    );
    await tester.pump();
    expect(
      tester.widget<ShotMapDiagram>(find.byType(ShotMapDiagram)).color,
      const Color(0xFFEF2C34),
    );
    final awayProgression =
        tester.widget<ProgressionDiagram>(find.byType(ProgressionDiagram));
    expect(awayProgression.color, const Color(0xFFEF2C34));
    expect(awayProgression.rightToLeft, isTrue);
    expect(
      tester
          .widget<DefenseTerritoryDiagram>(
            find.byType(DefenseTerritoryDiagram),
          )
          .zoneDeltas,
      [-25, 25, 0],
    );
    expect(
      tester
          .widget<DefenseTerritoryDiagram>(
            find.byType(DefenseTerritoryDiagram),
          )
          .selectedTeamColor,
      awayProgression.color,
    );
    expect(
      tester
          .widget<DefenseTerritoryDiagram>(
            find.byType(DefenseTerritoryDiagram),
          )
          .rightToLeft,
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: AnalysisTab(fixture: fixture, repository: repository),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Key Passes'), findsNothing);
    expect(find.text('Passes Into Final Third'), findsWidgets);
  });

  testWidgets('shows an honest unavailable state', (tester) async {
    final fixture = mockFixtures.first;
    final analysis = MatchTacticalAnalysis(
      fixtureId: fixture.fixtureId,
      available: false,
      home: null,
      away: null,
    );
    final shotMap = MatchShotMap(
      fixtureId: fixture.fixtureId,
      available: false,
      homeCount: null,
      awayCount: null,
      shots: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: AnalysisTab(
            fixture: fixture,
            repository: TestMatchAnalysisRepository(analysis, shotMap),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Tactical analysis is unavailable for this match.'),
      findsOneWidget,
    );
    expect(find.byType(ShotMapDiagram), findsNothing);
  });

  for (final scenario in [
    (size: const Size(320, 568), theme: app_style.darktheme),
    (size: const Size(430, 932), theme: app_style.whitetheme),
  ]) {
    testWidgets('shows Sportmonks key passes without Opta at ${scenario.size}',
        (tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = mockFixtures.first;
      final repository = TestMatchAnalysisRepository(
        MatchTacticalAnalysis(
          fixtureId: fixture.fixtureId,
          available: false,
          home: null,
          away: null,
        ),
        MatchShotMap(
          fixtureId: fixture.fixtureId,
          available: false,
          homeCount: null,
          awayCount: null,
          shots: const [],
        ),
      );
      final detail = _detailWithStatistics(
        fixture,
        [
          _keyPasses(fixture.homeTeamId, 0),
          _keyPasses(fixture.awayTeamId, 4),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        theme: scenario.theme,
        home: Scaffold(
          body: AnalysisTab(
            fixture: fixture,
            detail: detail,
            repository: repository,
          ),
        ),
      ));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('match-analysis-attack-card')),
        findsOneWidget,
      );
      expect(_keyPassRowText(tester), ['0', 'Key Passes', '4']);
      expect(find.text('Passes Into Final Third'), findsNothing);
      expect(find.byType(ShotMapDiagram), findsNothing);
      await tester.ensureVisible(find.text('Key Passes'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('attack shots reveal once when the pitch enters a compact view',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    const shots = [
      ShotMapPlot(
        start: Offset(0.2, 0.7),
        end: Offset(0.5, 1),
        isGoal: false,
      ),
      ShotMapPlot(
        start: Offset(0.7, 0.6),
        end: Offset(0.5, 1),
        isGoal: true,
      ),
      ShotMapPlot(
        start: Offset(0.5, 0.5),
        end: Offset(0.5, 1),
        isGoal: false,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: scroll,
          child: const Column(children: [
            SizedBox(height: 850),
            ShotMapDiagram(
              shots: shots,
              color: Colors.red,
              lineColor: Colors.white,
            ),
          ]),
        ),
      ),
    ));

    expect(_shotMapProgress(tester), 0);
    scroll.jumpTo(500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_shotMapProgress(tester), inInclusiveRange(0.1, 0.9));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_shotMapProgress(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(_shotMapProgress(tester), 1);
    scroll.jumpTo(0);
    await tester.pump();
    scroll.jumpTo(500);
    await tester.pump();
    expect(_shotMapProgress(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching attack teams replays the new shot map on a tall view',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = mockFixtures.first;
    final repository = TestMatchAnalysisRepository(
      MatchTacticalAnalysis(
        fixtureId: fixture.fixtureId,
        available: false,
        home: null,
        away: null,
      ),
      MatchShotMap(
        fixtureId: fixture.fixtureId,
        available: true,
        homeCount: 1,
        awayCount: 1,
        shots: [
          for (final teamId in [fixture.homeTeamId, fixture.awayTeamId])
            MatchShot(
              eventId: 'shot-$teamId',
              teamId: teamId,
              playerId: null,
              playerName: null,
              minute: 20,
              extraMinute: null,
              result: 'missed',
              start: const TacticalPitchPoint(x: 80, y: 45),
              end: const TacticalPitchPoint(x: 100, y: 50),
            ),
        ],
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home:
          Scaffold(body: AnalysisTab(fixture: fixture, repository: repository)),
    ));
    await tester.pump();
    await tester.ensureVisible(find.byType(ShotMapDiagram));
    await tester.pumpAndSettle();
    expect(_shotMapProgress(tester), 1);

    await tester.ensureVisible(
      find.byKey(const ValueKey('match-analysis-away-toggle')).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('match-analysis-away-toggle')).first,
    );
    await tester.pump();
    expect(_shotMapProgress(tester), 0);
    await tester.ensureVisible(find.byType(ShotMapDiagram));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_shotMapProgress(tester), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_shotMapProgress(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows every attack shot immediately',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: ShotMapDiagram(
            shots: [
              ShotMapPlot(
                start: Offset(0.4, 0.6),
                end: Offset(0.5, 1),
                isGoal: false,
              ),
            ],
            color: Colors.red,
            lineColor: Colors.white,
          ),
        ),
      ),
    ));
    expect(_shotMapProgress(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progression and defense start when scrolled into a compact view',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: scroll,
          child: const Column(children: [
            SizedBox(height: 750),
            ProgressionDiagram(
              lanePercents: (left: 22, center: 33, right: 45),
              color: Colors.red,
              labelColor: Colors.white,
            ),
            SizedBox(height: 350),
            DefenseTerritoryDiagram(
              zoneDeltas: [-20, 23, -3],
              selectedTeamColor: Colors.red,
              lineColor: Colors.white,
            ),
          ]),
        ),
      ),
    ));

    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)), 0);
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 0);
    scroll.jumpTo(400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)),
        inInclusiveRange(0.1, 0.9));
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 0);

    scroll.jumpTo(900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)),
        inInclusiveRange(0.1, 0.9));
    await tester.pumpAndSettle();
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)), 1);
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('team change replays both arrows in the reverse direction',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var away = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return Column(children: [
            TextButton(
              onPressed: () => setState(() => away = !away),
              child: const Text('switch team'),
            ),
            ProgressionDiagram(
              rightToLeft: away,
              lanePercents: (left: 22, center: 33, right: 45),
              color: Colors.red,
              labelColor: Colors.white,
            ),
            DefenseTerritoryDiagram(
              rightToLeft: away,
              zoneDeltas: const [-20, 23, -3],
              selectedTeamColor: Colors.red,
              lineColor: Colors.white,
            ),
          ]);
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)), 1);
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 1);

    await tester.tap(find.text('switch team'));
    await tester.pump();
    expect(
        tester
            .widget<ProgressionDiagram>(find.byType(ProgressionDiagram))
            .rightToLeft,
        isTrue);
    expect(
        tester
            .widget<DefenseTerritoryDiagram>(
                find.byType(DefenseTerritoryDiagram))
            .rightToLeft,
        isTrue);
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)), 0);
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)),
        inInclusiveRange(0.1, 0.9));
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)),
        inInclusiveRange(0.1, 0.9));
    await tester.pumpAndSettle();
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)), 1);
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion displays progression and defense arrows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              ProgressionDiagram(
                lanePercents: (left: 22, center: 33, right: 45),
                color: Colors.red,
                labelColor: Colors.white,
              ),
              DefenseTerritoryDiagram(
                zoneDeltas: [-20, 23, -3],
                selectedTeamColor: Colors.red,
                lineColor: Colors.white,
              ),
            ]),
          ),
        ),
      ),
    ));
    expect(_diagramProgress(tester, find.byType(ProgressionDiagram)), 1);
    expect(_diagramProgress(tester, find.byType(DefenseTerritoryDiagram)), 1);
    expect(tester.takeException(), isNull);
  });
}

double _shotMapProgress(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(ShotMapDiagram),
    matching: find.byType(CustomPaint),
  ));
  return ((paint.painter! as dynamic).reveal.value as double);
}

double _diagramProgress(WidgetTester tester, Finder diagram) {
  final paint = tester.widget<CustomPaint>(find.descendant(
    of: diagram,
    matching: find.byType(CustomPaint),
  ));
  return ((paint.painter! as dynamic).reveal.value as double);
}

FixtureDetail _detailWithStatistics(
  Fixture fixture,
  List<FixtureStatistic> statistics,
) =>
    FixtureDetail(
      fixture: fixture,
      venueName: null,
      expectedGoals: null,
      playerExpectedGoals: const [],
      shots: const [],
      events: const [],
      statistics: statistics,
      lineups: const [],
      formations: const [],
      coaches: const [],
      pressure: const [],
    );

Iterable<String?> _keyPassRowText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.widgetWithText(Row, 'Key Passes'),
      matching: find.byType(Text),
    ))
    .map((text) => text.data);

FixtureStatistic _keyPasses(int teamId, double value) => FixtureStatistic(
      teamId: teamId,
      statTypeId: 117,
      statCode: 'key-passes',
      statName: 'Key Passes',
      value: value,
    );

FixtureStatistic _stat(int teamId, String code, double value) =>
    FixtureStatistic(
      teamId: teamId,
      statTypeId: 0,
      statCode: code,
      statName: code,
      value: value,
    );

MatchTeamTacticalAnalysis _team(
  int teamId, {
  required int keyPasses,
  required int recoveries,
  List<TacticalPitchPoint> actions = const [
    TacticalPitchPoint(x: 60, y: 40),
  ],
}) =>
    MatchTeamTacticalAnalysis(
      teamId: teamId,
      attack: MatchAttackMetrics(
        keyPasses: keyPasses,
        completedPassesIntoFinalThird: keyPasses * 4,
      ),
      progression: MatchProgressionMetrics(
        completedPasses: 300,
        progressivePasses: 30,
        channels: const MatchProgressionChannels(
          left: MatchProgressionChannel(
            count: 10,
            percentage: 33.33,
          ),
          center: MatchProgressionChannel(
            count: 12,
            percentage: 40,
          ),
          right: MatchProgressionChannel(
            count: 8,
            percentage: 26.67,
          ),
        ),
      ),
      defensiveActivity: MatchDefensiveActivity(
        complete: true,
        missingPositionCount: 0,
        actionCount: actions.length,
        actions: actions,
        recoveries: recoveries,
        highRegains: 5,
        ownHalfPercentage: 60,
        opponentHalfPercentage: 40,
        averageRegainX: 42,
        averageRegainHeightMetres: 44.5,
      ),
    );
