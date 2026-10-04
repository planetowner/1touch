import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/screens/TeamProbabilityScreen.dart';
import 'package:onetouch/screens/team_probability_what_if_screen.dart';

void main() {
  for (final size in [const Size(393, 852), const Size(430, 932)]) {
    testWidgets('history chart fits the shared design at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'league_winner',
          initialSnapshot: _snapshot(),
        ),
      ));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('probability-history-card'));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(card).height, RoundChartVisuals.cardHeight);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('probability-history-viewport')),
      );
      await tester.tapAt(viewport.center);
      await tester.pump();
      final tooltip = tester.getRect(
        find.byKey(const ValueKey('probability-history-tooltip')),
      );
      expect(tooltip.left, greaterThanOrEqualTo(viewport.left));
      expect(tooltip.right, lessThanOrEqualTo(viewport.right));
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.text('32.4'), findsOneWidget);
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
    expect(historyViewport.left, historyGrid.left);
    expect(historyViewport.right, historyGrid.right);
    expect(historyLineChart.width, historyViewport.width * 2);
    final historyData = tester
        .widget<LineChart>(
          find.byKey(const ValueKey('probability-history-line-chart')),
        )
        .data;
    expect((historyData.minX, historyData.maxX), (-2, 10));
    expect(historyData.lineBarsData.single.spots.map((spot) => spot.x), [4, 5]);
    expect((historyData.minY, historyData.maxY), (20, 40));
    final historyCardFinder =
        find.byKey(const ValueKey('probability-history-card'));
    expect(
      find.descendant(
        of: historyCardFinder,
        matching: find.byKey(const ValueKey('probability-history-axis-label')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: historyCardFinder,
        matching: find.byKey(const ValueKey('probability-history-round-label')),
      ),
      findsOneWidget,
    );
    expect(
        (tester.widget<Container>(historyCardFinder).decoration!
                as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(RoundChartVisuals.cardRadius));
    final gridPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('probability-history-grid')),
        )
        .painter! as RoundChartGridPainter;
    expect(gridPainter.divisionCount + 1, 12);
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
    expect(find.text('Round 5'), findsOneWidget);
    await tester.tapAt(historyViewport.center);
    await tester.pump();
    expect(find.text('Round 5'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('probability-history-selector-line')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('probability-history-tooltip')),
      findsOneWidget,
    );
    final historyHandle = find.descendant(
      of: find.byKey(const ValueKey('probability-history-viewport')),
      matching: find.byKey(const ValueKey('round-chart-selection-handle')),
    );
    expect(
        tester.getRect(historyHandle).left + RoundChartSelectionHandle.tipInset,
        closeTo(historyViewport.center.dx, 0.1));
    expect(tester.getRect(historyHandle).top,
        historyViewport.bottom - RoundChartSelectionHandle.height);
    final drag = await tester.startGesture(tester.getCenter(historyHandle));
    await drag.moveBy(Offset(-historyViewport.width / 6, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('Round 4'), findsOneWidget);
    expect(find.text('26%'), findsOneWidget);
    final dynamic selectionPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('probability-history-selector-line')),
        )
        .painter;
    expect(selectionPainter.round, 4);
    final tooltipRect = tester.getRect(
      find.byKey(const ValueKey('probability-history-tooltip')),
    );
    expect(tooltipRect.left, greaterThanOrEqualTo(historyViewport.left));
    expect(tooltipRect.right, lessThanOrEqualTo(historyViewport.right));
    expect(
        tester.getRect(historyHandle).left + RoundChartSelectionHandle.tipInset,
        closeTo(historyViewport.center.dx, 0.1));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('probability-history-tooltip')))
          .center
          .dy,
      closeTo(historyChart.top + historyChart.height * 0.7, 1),
    );
    final nextDrag = await tester.startGesture(tester.getCenter(historyHandle));
    await nextDrag.moveBy(Offset(historyViewport.width / 6, 0));
    await nextDrag.up();
    await tester.pumpAndSettle();
    expect(find.text('Round 5'), findsOneWidget);
    expect(
        tester.getRect(historyHandle).left + RoundChartSelectionHandle.tipInset,
        closeTo(historyViewport.center.dx, 0.1));
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
    for (final (index, outcome) in ['win', 'draw', 'loss'].indexed) {
      final option = find.byKey(ValueKey('what-if-outcome-$outcome'));
      final labels = find.descendant(of: option, matching: find.byType(Text));
      expect(labels, findsNWidgets(2));
      final first = tester.getRect(labels.first);
      final last = tester.getRect(labels.last);
      expect((first.top + last.bottom) / 2,
          closeTo(tester.getRect(option).center.dy, 0.1));
      expect(
          find.descendant(
              of: option, matching: find.text('(${[55, 25, 20][index]}%)')),
          findsOneWidget);
    }
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('projected-points-card')),
      200,
      scrollable: find.byWidgetPredicate((widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down),
    );
    expect(find.text('예상 승점은 75–90점이에요', findRichText: true), findsOneWidget);
    expect(find.text('5R'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in [
    (
      event: 'league_winner',
      teamId: 83,
      unchanged: false,
      expected: '바르셀로나가 이기면 우승 확률이 5.6%p 올라요. 지면 11.4%p 내려가요.'
    ),
    (
      event: 'league_winner',
      teamId: 90,
      unchanged: false,
      expected: '헤타페가 이기면 우승 확률이 5.6%p 올라요. 지면 11.4%p 내려가요.'
    ),
    (
      event: 'direct_relegation',
      teamId: 83,
      unchanged: false,
      expected: '바르셀로나가 이기면 강등 확률이 4.0%p 내려가요. 지면 5.0%p 올라요.'
    ),
    (
      event: 'league_winner',
      teamId: 83,
      unchanged: true,
      expected: '바르셀로나가 이기면 우승 확률이 그대로예요. 지면 그대로예요.'
    ),
  ]) {
    testWidgets('Korean what-if uses localized fixture labels: $testCase',
        (tester) async {
      tester.view.physicalSize = const Size(320, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousLocale = appLocaleController.value;
      appLocaleController.value = const Locale('ko');
      addTearDown(() => appLocaleController.value = previousLocale);
      final snapshot = _snapshot(
          teamId: testCase.teamId,
          winProbability: testCase.unchanged ? 0.324 : 0.38,
          lossProbability: testCase.unchanged ? 0.324 : 0.21);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darkThemeForLocale(const Locale('ko')),
        home: FootballNamesScope(
          names: const FootballNames(
            teams: {83: 'FC 바르셀로나', 90: '헤타페 CF'},
            teamShortNames: {83: '바르셀로나', 90: '헤타페'},
            competitions: {564: '라리가'},
          ),
          child: TeamProbabilityWhatIfScreen(
            snapshot: snapshot,
            event: testCase.event,
            teamPrimaryColor: const Color(0xFFA50044),
            homeTeam: const Team(
                teamId: 83,
                name: 'FC Barcelona',
                shortName: 'Barcelona',
                shortCode: 'BAR'),
            awayTeam: const Team(teamId: 90, name: 'Getafe', shortCode: 'GET'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final team = testCase.teamId == 83 ? '바르셀로나' : '헤타페';
      expect(find.text('$team의 다음 경기 결과를 골라봐요'), findsOneWidget);
      expect(find.text('라리가 6R'), findsOneWidget);
      expect(
          find.text(fixtureDateLabel(snapshot.whatIf!.fixture.startingAt,
              locale: const Locale('ko'))),
          findsOneWidget);
      final titleRect = tester.getRect(find.text('다음 경기가 이렇게 끝나면?'));
      expect(
          titleRect.left,
          greaterThanOrEqualTo(tester
              .getRect(find.byKey(const ValueKey('what-if-back-button')))
              .right));
      expect(
          titleRect.right,
          lessThanOrEqualTo(tester
              .getRect(find.byKey(const ValueKey('what-if-search-button')))
              .left));
      expect(find.text('바르셀로나 승'), findsOneWidget);
      expect(find.text('헤타페 승'), findsOneWidget);
      expect(find.text('무승부'), findsOneWidget);
      for (final label in ['바르셀로나 승', '헤타페 승', '무승부']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
            of: find.text(label), matching: find.byType(RichText)));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      final winOption = find.byKey(const ValueKey('what-if-outcome-win'));
      expect(find.descendant(of: winOption, matching: find.text('$team 승')),
          findsOneWidget);
      expect(
          find.descendant(
              of: winOption,
              matching: find.text(testCase.teamId == 83 ? '(55%)' : '(20%)')),
          findsOneWidget);
      await tester.tap(winOption);
      await tester.pump();
      await tester.scrollUntilVisible(find.text(testCase.expected), 200);
      expect(find.text(testCase.expected), findsOneWidget);
      for (final label in ['이기면', '비기면', '지면']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

TeamProbabilitySnapshot _snapshot(
    {int teamId = 83,
    double winProbability = 0.38,
    double lossProbability = 0.21}) {
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
    teamId: teamId,
    teamName: teamId == 83 ? 'FC Barcelona' : 'Getafe',
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
        _scenario('win', winProbability),
        _scenario('draw', 0.29),
        _scenario('loss', lossProbability),
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
      TeamProbabilityCard(
        event: 'direct_relegation',
        competitionId: 564,
        category: 'RELEGATION',
        probability: switch (outcome) {
          'win' => 0.04,
          'draw' => 0.08,
          _ => 0.13
        },
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
