import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
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
    final detail = FixtureDetail(
      fixture: fixture,
      venueName: null,
      expectedGoals: null,
      playerExpectedGoals: const [],
      shots: const [],
      events: const [],
      statistics: [
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
      ],
      lineups: const [],
      formations: const [],
      coaches: const [],
      pressure: const [],
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
    expect(find.byType(DefensiveActivityDiagram), findsOneWidget);
    expect(find.text('DEFENSIVE ACTIVITY'), findsOneWidget);
    expect(find.text('PRESSURE'), findsNothing);
    expect(find.text('Carries into Final Third'), findsNothing);
    expect(find.text('Key Passes'), findsOneWidget);
    expect(find.text('Recoveries'), findsOneWidget);
    expect(find.text('Ball Possession'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
}

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
