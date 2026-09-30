import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/screens/TeamProbabilityScreen.dart';

void main() {
  testWidgets('renders the probability detail with the shared header gradient',
      (tester) async {
    const teamPrimaryColor = Color(0xFF123456);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'league_winner',
          initialSnapshot: _snapshot(),
          teamPrimaryColor: teamPrimaryColor,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Probability'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.text('Chances to Win\nLeague Trophy'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('team-probability-gradient')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('probability-search-button')),
          )
          .dy,
      app_style.appBarMinimumContentTop,
    );
    expect(
      tester
              .getBottomLeft(
                find.byKey(const ValueKey('team-probability-gradient')),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('probability-event-title')),
              )
              .dy,
      closeTo(32, 0.1),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('probability-event-title')),
          )
          .style
          ?.fontSize,
      Body1.style.fontSize,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('probability-detail-delta-icon')),
          )
          .color,
      teamPrimaryColor,
    );
    final fixedWhatIfButtonTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('probability-what-if-button')),
        )
        .dy;
    expect(
        find.byKey(const ValueKey('probability-history-card')), findsOneWidget);
    final historyCard = tester.getRect(
      find.byKey(const ValueKey('probability-history-card')),
    );
    final historyGrid = tester.getRect(
      find.byKey(const ValueKey('probability-history-grid')),
    );
    final historyLineChart = tester.getRect(
      find.byKey(const ValueKey('probability-history-line-chart')),
    );
    final historyViewport = tester.getRect(
      find.byKey(const ValueKey('probability-history-viewport')),
    );
    expect(historyGrid.left - historyCard.left, 16);
    expect(historyCard.right - historyGrid.right, 16);
    expect(historyViewport.left - historyGrid.left, 32);
    expect(historyViewport.right, historyGrid.right);
    expect(historyLineChart.width, historyViewport.width);
    final historyData = tester
        .widget<LineChart>(
          find.byKey(const ValueKey('probability-history-line-chart')),
        )
        .data;
    expect((historyData.minX, historyData.maxX), (1, 7));
    expect(historyData.lineBarsData.single.spots.map((spot) => spot.x), [4, 5]);
    expect((historyData.minY, historyData.maxY), (20, 40));
    final historyCardFinder =
        find.byKey(const ValueKey('probability-history-card'));
    expect(find.descendant(of: historyCardFinder, matching: find.text('40%')),
        findsOneWidget);
    expect(find.descendant(of: historyCardFinder, matching: find.text('30%')),
        findsOneWidget);
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .first
          .color,
      teamPrimaryColor,
    );

    final historyChart = tester.getRect(
      find.byKey(const ValueKey('probability-history-chart')),
    );
    final roundFourX = historyViewport.left + 1;
    await tester.tapAt(Offset(roundFourX, historyChart.center.dy));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('probability-history-selector-line')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('probability-history-tooltip')),
      findsOneWidget,
    );
    expect(find.text('Round 4'), findsOneWidget);
    expect(find.text('26%'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('probability-history-tooltip')))
          .center
          .dy,
      closeTo(historyChart.top + historyChart.height * 0.7, 1),
    );
    expect(find.text('PROJECTED FINAL POSITION'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('projected-position-1')),
          )
          .style
          ?.fontSize,
      Body2_b.style.fontSize,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first,
          )
          .color,
      teamPrimaryColor,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('projected-points-card')),
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('82.4'), findsOneWidget);
    expect(find.text('Likely range of 75–90 pts'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('projected-points-delta-icon')),
          )
          .color,
      teamPrimaryColor,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('probability-what-if-button')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('probability-what-if-button')),
          )
          .dy,
      fixedWhatIfButtonTop,
    );
    await tester.tap(find.byKey(const ValueKey('probability-what-if-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('team-probability-what-if-screen')),
      findsOneWidget,
    );
    expect(find.text('LEAGUE WINNER PROBABILITY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('what-if-scenario-chart')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('what-if-outcome-win')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('relegation probability displays the last five positions',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'direct_relegation',
          initialSnapshot: _snapshot(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);
    expect(
        find.byKey(const ValueKey('probability-history-card')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('probability-history-card')),
      200,
      scrollable: find.byWidgetPredicate((widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down),
    );

    final historyData = tester
        .widget<LineChart>(
          find.byKey(const ValueKey('probability-history-line-chart')),
        )
        .data;
    expect((historyData.minY, historyData.maxY), (0, 15));

    expect(
      find.byKey(const ValueKey('projected-position-1')),
      findsNothing,
    );
    for (final position in [16, 17, 18, 19, 20]) {
      expect(
        find.byKey(ValueKey('projected-position-$position')),
        findsOneWidget,
      );
    }
    final twentieth = tester.widget<Text>(
      find.byKey(const ValueKey('projected-position-20')),
    );
    expect(twentieth.maxLines, 1);
    expect(twentieth.softWrap, isFalse);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('projected-position-20')),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      40,
    );
    final twentiethPercentage = tester.widget<Text>(
      find.byKey(const ValueKey('projected-position-percentage-20')),
    );
    expect(twentiethPercentage.maxLines, 1);
    expect(twentiethPercentage.softWrap, isFalse);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey('projected-position-percentage-20'),
                  ),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      40,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Korean probability title aligns with the percentage bottom',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previousLocale = appLocaleController.value;
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = previousLocale);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darkThemeForLocale(const Locale('ko')),
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'league_winner',
          initialSnapshot: _snapshot(),
        ),
      ),
    );
    await tester.pump();

    final valueBottom = tester
        .getBottomLeft(
          find.byKey(const ValueKey('probability-detail-value')),
        )
        .dy;
    final titleBottom = tester
        .getBottomLeft(
          find.byKey(const ValueKey('probability-event-title')),
        )
        .dy;
    expect(titleBottom, closeTo(valueBottom, 0.1));
    expect(find.text('리그 우승 확률'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TeamProbabilitySnapshot _snapshot() {
  const currentCard = TeamProbabilityCard(
    event: 'league_winner',
    competitionId: 564,
    category: 'TITLE',
    probability: 0.324,
    changePercentagePoints: 2.4,
    entropy: 0.9,
  );
  const relegationCard = TeamProbabilityCard(
    event: 'direct_relegation',
    competitionId: 564,
    category: 'RELEGATION',
    probability: 0.08,
    changePercentagePoints: -1.2,
    entropy: 0.4,
  );
  return TeamProbabilitySnapshot(
    teamId: 83,
    teamName: 'FC Barcelona',
    competitionId: 564,
    seasonId: 27965,
    seasonName: '2026/2027',
    asOf: DateTime.utc(2026, 9, 18),
    maximumPoints: 114,
    positions: const [
      TeamPositionProbability(position: 1, probability: 0.5),
      TeamPositionProbability(position: 2, probability: 0.3),
      TeamPositionProbability(position: 3, probability: 0.1),
      TeamPositionProbability(position: 4, probability: 0.06),
      TeamPositionProbability(position: 5, probability: 0.04),
      TeamPositionProbability(position: 16, probability: 0.04),
      TeamPositionProbability(position: 17, probability: 0.06),
      TeamPositionProbability(position: 18, probability: 0.1),
      TeamPositionProbability(position: 19, probability: 0.3),
      TeamPositionProbability(position: 20, probability: 0.5),
    ],
    projectedPoints: const TeamProjectedPoints(
      mean: 82.4,
      likelyRange: TeamPointsInterval(lower: 75, upper: 90),
      changePoints: 1.2,
    ),
    comparison: TeamProbabilityComparison(
      available: true,
      asOf: DateTime.utc(2026, 9, 11),
    ),
    cards: const [currentCard, relegationCard],
    history: [
      TeamProbabilityHistoryPoint(
        asOf: DateTime.utc(2026, 9, 11),
        played: 4,
        events: const [
          TeamProbabilityCard(
            event: 'league_winner',
            competitionId: 564,
            category: 'TITLE',
            probability: 0.26,
            changePercentagePoints: null,
            entropy: null,
          ),
        ],
        expectedPoints: 80.8,
      ),
      TeamProbabilityHistoryPoint(
        asOf: DateTime.utc(2026, 9, 18),
        played: 5,
        events: const [currentCard, relegationCard],
        expectedPoints: 82.4,
      ),
    ],
    pendingOutcomes: const [],
    whatIf: TeamProbabilityWhatIf(
      fixture: TeamProbabilityWhatIfFixture(
        fixtureId: 100,
        homeTeamId: 83,
        awayTeamId: 90,
        startingAt: DateTime.utc(2026, 9, 27, 19),
        roundName: '6',
        probabilities: const [0.55, 0.25, 0.2],
      ),
      scenarios: [
        _scenario('win', 0.38),
        _scenario('draw', 0.29),
        _scenario('loss', 0.21),
      ],
    ),
  );
}

TeamProbabilityWhatIfScenario _scenario(String outcome, double probability) {
  return TeamProbabilityWhatIfScenario(
    outcome: outcome,
    events: [
      TeamProbabilityCard(
        event: 'league_winner',
        competitionId: 564,
        category: 'TITLE',
        probability: probability,
        changePercentagePoints: null,
        entropy: null,
      ),
    ],
    positions: const [],
    projectedPoints: const TeamProjectedPoints(
      mean: 82.4,
      likelyRange: TeamPointsInterval(lower: 75, upper: 90),
      changePoints: null,
    ),
  );
}
