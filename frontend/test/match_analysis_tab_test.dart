import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';
import 'package:onetouch/screens/MatchScreen_tabs/Anal.dart';

void main() {
  testWidgets('renders real tactical values without the former pressure mocks',
      (tester) async {
    final fixture = mockFixtures.first;
    final analysis = MatchTacticalAnalysis(
      fixtureId: fixture.fixtureId,
      available: true,
      home: _team(fixture.homeTeamId, keyPasses: 7, recoveries: 21),
      away: _team(fixture.awayTeamId, keyPasses: 2, recoveries: 14),
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
    final repository = _Repository(analysis, shotMap);
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
    expect(find.byType(DefensiveActivityDiagram), findsOneWidget);
    expect(find.text('DEFENSE'), findsOneWidget);
    expect(find.text('PRESSURE'), findsOneWidget);
    expect(find.text('Carries into Final Third'), findsNothing);
    expect(find.text('Key Passes'), findsOneWidget);
    expect(_keyPassRowText(tester), ['25', 'Key Passes', '4']);
    expect(find.text('Recoveries'), findsOneWidget);
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
            repository: _Repository(analysis, shotMap),
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
      final repository = _Repository(
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

MatchTeamTacticalAnalysis _team(
  int teamId, {
  required int keyPasses,
  required int recoveries,
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
        actionCount: 1,
        actions: const [TacticalPitchPoint(x: 60, y: 40)],
        recoveries: recoveries,
        highRegains: 5,
        ownHalfPercentage: 60,
        opponentHalfPercentage: 40,
        averageRegainX: 42,
        averageRegainHeightMetres: 44.5,
      ),
    );

class _Repository implements MatchAnalysisRepository {
  _Repository(this.analysis, this.shotMap)
      : cachedAnalyses = ValueNotifier({analysis.fixtureId: analysis}),
        cachedShotMaps = ValueNotifier({shotMap.fixtureId: shotMap});

  final MatchTacticalAnalysis analysis;
  final MatchShotMap shotMap;

  @override
  final ValueNotifier<Map<int, MatchTacticalAnalysis>> cachedAnalyses;

  @override
  final ValueNotifier<Map<int, MatchShotMap>> cachedShotMaps;

  @override
  MatchTacticalAnalysis? cachedAnalysisForFixture(int fixtureId) =>
      cachedAnalyses.value[fixtureId];

  @override
  MatchShotMap? cachedShotMapForFixture(int fixtureId) =>
      cachedShotMaps.value[fixtureId];

  @override
  Future<MatchTacticalAnalysis> loadAnalysis(int fixtureId) async => analysis;

  @override
  Future<MatchShotMap> loadShotMap(int fixtureId) async => shotMap;
}
