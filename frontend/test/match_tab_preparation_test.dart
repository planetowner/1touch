import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/highlights/fixture_highlight_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/fixture_highlight.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';
import 'package:onetouch/screens/MatchScreen.dart';
import 'package:onetouch/screens/MatchScreen_tabs/anal.dart';
import 'support/app_catalog.dart';
import 'support/fake_betting_repository.dart';
import 'support/test_match_analysis_repository.dart';

void main() {
  setUpAppCatalog();

  testWidgets(
      'prepares ordinary tabs on entry and keeps H2H, analysis and highlights when switching',
      (tester) async {
    final fixtures = _Fixtures();
    final analysis = _Analysis();
    final highlights = _Highlights();
    await tester.pumpWidget(MaterialApp(
        home: MatchScreen(
      matchId: '${_fixture.fixtureId}',
      matchStatus: 'past',
      repository: fixtures,
      analysisRepository: analysis,
      highlightRepository: highlights,
      bettingRepository: FakeBettingRepository(),
    )));
    await tester.pump();
    expect(fixtures.limits, [5]);
    expect(analysis.calls, [1, 1]);
    expect(highlights.calls, 1);
    expect(find.text('HIGHLIGHTS UNAVAILABLE'), findsNothing);

    fixtures.responses.single.complete([_fixture]);
    analysis.complete();
    highlights.response.complete(FixtureHighlight(
        fixtureId: _fixture.fixtureId,
        videoUrl: 'https://www.youtube.com/watch?v=test',
        title: 'Highlights',
        thumbnailUrl: null));
    await tester.pumpAndSettle();
    final highlightState = tester.state(find.byType(MatchHighlights));

    Future<void> select(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.byType(FootballLoadingIndicator), findsNothing);
    }

    await select('HEAD TO HEAD');
    expect(find.byKey(const ValueKey('match-h2h-wdl-card')), findsOneWidget);
    final dropdown = tester.widget<AppDropdown<int>>(
        find.byKey(const ValueKey('match-h2h-limit-dropdown')));
    dropdown.onChanged(10);
    await tester.pump();
    expect(fixtures.limits, [5, 10]);
    fixtures.responses.last.complete([_fixture]);
    await tester.pumpAndSettle();

    await select('ANALYSIS');
    final analysisState = tester.state(find.byType(AnalysisTab));
    expect(find.byKey(const ValueKey('match-analysis-attack-card')),
        findsOneWidget);
    for (var repeat = 0; repeat < 2; repeat++) {
      await select('MATCH INFO');
      expect(tester.state(find.byType(MatchHighlights)), same(highlightState));
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.text('HIGHLIGHTS UNAVAILABLE'), findsNothing);
      await select('HEAD TO HEAD');
      expect(
          tester
              .widget<AppDropdown<int>>(
                  find.byKey(const ValueKey('match-h2h-limit-dropdown')))
              .value,
          10);
      await select('ANALYSIS');
      expect(tester.state(find.byType(AnalysisTab)), same(analysisState));
    }
    expect(fixtures.limits, [5, 10]);
    expect(analysis.calls, [1, 1]);
    expect(highlights.calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('analysis waits for the graphs before placing defense below them',
      (tester) async {
    final analysis = _Analysis();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnalysisTab(
      fixture: _fixture,
      detail: _detail,
      repository: analysis,
    ))));
    await tester.pump();
    expect(find.byType(FootballLoadingIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('match-analysis-defense-card')),
        findsNothing);
    analysis.complete();
    await tester.pumpAndSettle();
    final defense = find.byKey(const ValueKey('match-analysis-defense-card'));
    final attack = find.byKey(const ValueKey('match-analysis-attack-card'));
    expect(defense, findsOneWidget);
    expect(tester.getTopLeft(defense).dy,
        greaterThan(tester.getBottomLeft(attack).dy));
    final position = tester.getTopLeft(defense);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(defense), position);
    expect(tester.takeException(), isNull);
  });
}

final _fixture =
    mockFixtures.firstWhere((fixture) => fixture.status == FixtureStatus.past);
final _detail = FixtureDetail(
    fixture: _fixture,
    venueName: null,
    expectedGoals: null,
    playerExpectedGoals: const [],
    shots: const [],
    events: const [],
    statistics: [
      for (final teamId in [_fixture.homeTeamId, _fixture.awayTeamId])
        FixtureStatistic(
            teamId: teamId,
            statTypeId: 1,
            statCode: 'tackles-won',
            statName: 'Tackles Won',
            value: 3),
    ],
    lineups: const [],
    formations: const [],
    coaches: const [],
    pressure: const []);

class _Fixtures extends MockFixtureRepository {
  _Fixtures() : super(fixtures: [_fixture], fixtureDetails: [_detail]);
  final limits = <int>[];
  final responses = <Completer<List<Fixture>>>[];
  @override
  Future<List<Fixture>> loadHeadToHead(int fixtureId, {int limit = 10}) {
    limits.add(limit);
    final response = Completer<List<Fixture>>();
    responses.add(response);
    return response.future;
  }
}

class _Analysis extends TestMatchAnalysisRepository {
  _Analysis()
      : super(
            MatchTacticalAnalysis(
                fixtureId: _fixture.fixtureId,
                available: false,
                home: null,
                away: null),
            MatchShotMap(
                fixtureId: _fixture.fixtureId,
                available: true,
                homeCount: 1,
                awayCount: 0,
                shots: [
                  MatchShot(
                      eventId: 'shot',
                      teamId: _fixture.homeTeamId,
                      playerId: null,
                      playerName: null,
                      minute: 10,
                      extraMinute: null,
                      result: 'goal',
                      start: const TacticalPitchPoint(x: 80, y: 40),
                      end: const TacticalPitchPoint(x: 100, y: 50)),
                ]));
  final calls = [0, 0];
  final pendingAnalysis = Completer<MatchTacticalAnalysis>();
  final pendingShots = Completer<MatchShotMap>();
  @override
  MatchTacticalAnalysis? cachedAnalysisForFixture(int fixtureId) => null;
  @override
  MatchShotMap? cachedShotMapForFixture(int fixtureId) => null;
  @override
  Future<MatchTacticalAnalysis> loadAnalysis(int fixtureId) {
    calls[0]++;
    return pendingAnalysis.future;
  }

  @override
  Future<MatchShotMap> loadShotMap(int fixtureId) {
    calls[1]++;
    return pendingShots.future;
  }

  void complete() {
    pendingAnalysis.complete(analysis);
    pendingShots.complete(shotMap);
  }
}

class _Highlights implements FixtureHighlightRepository {
  int calls = 0;
  final response = Completer<FixtureHighlight?>();
  @override
  Future<FixtureHighlight?> loadForFixture(int fixtureId) {
    calls++;
    return response.future;
  }
}
