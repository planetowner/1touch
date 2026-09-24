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
import 'package:onetouch/screens/MatchScreen_tabs/Anal.dart';

void main() {
  setUpAppCatalog();
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
    expect(defenseTerritoryOpacity(-20.8), closeTo(0.292, 0.0001));
    expect(defenseTerritoryOpacity(23.4), closeTo(0.734, 0.0001));
    expect(defenseTerritoryOpacity(-2.7), closeTo(0.473, 0.0001));
    final arrowShaft = defenseTerritoryArrowShaftRect(
      const Size(334, 208.75),
    );
    expect(arrowShaft.width, 233);
    expect(arrowShaft.height, 28);
    expect(arrowShaft.left, lessThan(334 / 3));
    expect(arrowShaft.right, greaterThan(334 * 2 / 3));
    expect(arrowShaft.top, 208.75 / 2);
    final arrowHeadTop = arrowShaft.center.dy - 208.75 * 0.18;
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
      app_style.AppPalette.white,
    );
    expect(
      (awayToggle.decoration as BoxDecoration).color,
      app_style.AppPalette.lightModeDarkGrey,
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
    expect(find.text('Passes into Final Third'), findsWidgets);
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
      expect(find.text('Passes into Final Third'), findsNothing);
      expect(find.byType(ShotMapDiagram), findsNothing);
      await tester.ensureVisible(find.text('Key Passes'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
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
        channels: const [
          MatchProgressionChannel(
            channel: 'left',
            count: 10,
            percentage: 33.33,
          ),
          MatchProgressionChannel(
            channel: 'center',
            count: 12,
            percentage: 40,
          ),
          MatchProgressionChannel(
            channel: 'right',
            count: 8,
            percentage: 26.67,
          ),
        ],
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
