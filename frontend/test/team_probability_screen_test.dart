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
  for (final locale in const [Locale('en'), Locale('ko')]) {
    for (final width in [320.0, 360.0, 393.0, 430.0]) {
      testWidgets(
          '${locale.languageCode} relegation playoff title fits at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousLocale = appLocaleController.value;
        appLocaleController.value = locale;
        addTearDown(() => appLocaleController.value = previousLocale);

        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: app_style.darkThemeForLocale(locale),
          home: TeamProbabilityScreen(
            teamId: 83,
            event: 'relegation_playoff',
            initialSnapshot: _snapshot(relegationEvent: 'relegation_playoff'),
          ),
        ));
        await tester.pumpAndSettle();

        final title = find.byKey(const ValueKey('probability-event-title'));
        final titleWidget = tester.widget<Text>(title);
        expect(
            titleWidget.data,
            locale.languageCode == 'ko'
                ? '강등 플레이오프 확률'
                : 'Chances to\nRelegation Playoff');
        expect(titleWidget.style?.fontSize, Body1.style.fontSize);
        expect(find.ancestor(of: title, matching: find.byType(FittedBox)),
            findsNothing);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: title, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(360, 780),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
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
    expect(find.text('2.4%'), findsOneWidget);
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
    expect(historyLineChart.width, closeTo(historyViewport.width, 0.1));
    final historyData = tester
        .widget<LineChart>(
          find.byKey(const ValueKey('probability-history-line-chart')),
        )
        .data;
    expect((historyData.minX, historyData.maxX), (0, 14));
    expect(historyData.lineBarsData.single.spots.map((spot) => spot.x), [4, 5]);
    expect((historyData.minY, historyData.maxY), (0, 40));
    final historyCardFinder =
        find.byKey(const ValueKey('probability-history-card'));
    expect(
      find.descendant(
        of: historyCardFinder,
        matching: find.byKey(const ValueKey('probability-history-top-label')),
      ),
      findsOneWidget,
    );
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(
      tester
          .getCenter(
              find.byKey(const ValueKey('probability-history-middle-label')))
          .dy,
      closeTo(historyGrid.center.dy, 0.1),
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
    expect(gridPainter.insetLineCount, 0);
    final topMask = tester.getRect(find
        .ancestor(
          of: find.byKey(const ValueKey('probability-history-top-label')),
          matching: find.byType(ColoredBox),
        )
        .first);
    final middleMask = tester.getRect(find
        .ancestor(
          of: find.byKey(const ValueKey('probability-history-middle-label')),
          matching: find.byType(ColoredBox),
        )
        .first);
    expect(topMask.width, lessThan(RoundChartVisuals.axisLineInset));
    for (var index = 0; index <= gridPainter.divisionCount; index++) {
      final lineY = historyGrid.top +
          historyGrid.height * index / gridPainter.divisionCount;
      if ((lineY >= topMask.top && lineY <= topMask.bottom) ||
          (lineY >= middleMask.top && lineY <= middleMask.bottom)) {
        expect(gridPainter.insetLineIndices, contains(index));
      }
    }
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
        closeTo(historyViewport.left + historyViewport.width * 5 / 14, 0.1));
    expect(tester.getRect(historyHandle).top,
        historyViewport.bottom - RoundChartSelectionHandle.height);
    final drag = await tester.startGesture(tester.getCenter(historyHandle));
    await drag.moveBy(Offset(-historyViewport.width / 14, 0));
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
        closeTo(
            tester
                    .getRect(find
                        .byKey(const ValueKey('probability-history-viewport')))
                    .left +
                historyViewport.width * 4 / 14,
            0.1));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('probability-history-tooltip')))
          .center
          .dy,
      closeTo(historyChart.top + historyChart.height * 0.35, 1),
    );
    final nextDrag = await tester.startGesture(tester.getCenter(historyHandle));
    await nextDrag.moveBy(Offset(historyViewport.width / 14, 0));
    await nextDrag.up();
    await tester.pumpAndSettle();
    expect(find.text('Round 5'), findsOneWidget);
    expect(
        tester.getRect(historyHandle).left + RoundChartSelectionHandle.tipInset,
        closeTo(historyViewport.left + historyViewport.width * 5 / 14, 0.1));
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
    expect(find.text('1.3%'), findsOneWidget);
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
    for (final outcome in ['win', 'draw', 'loss']) {
      final option = find.byKey(ValueKey('what-if-outcome-$outcome'));
      final labels = find.descendant(of: option, matching: find.byType(Text));
      expect(labels, findsOneWidget);
      expect(
          tester.getRect(labels).center.dy,
          closeTo(
              tester
                  .getRect(
                      find.byKey(ValueKey('what-if-outcome-logo-$outcome')))
                  .center
                  .dy,
              0.1));
    }
    await tester.tap(find.byKey(const ValueKey('what-if-outcome-win')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('what-if outcome labels align with logos at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityWhatIfScreen(
          snapshot: _snapshot(),
          event: 'league_winner',
          teamPrimaryColor: const Color(0xFFA50044),
          homeTeam: const Team(
              teamId: 83, name: 'FC Barcelona', shortName: 'Barcelona'),
          awayTeam: const Team(teamId: 90, name: 'Girona FC'),
        ),
      ));
      await tester.pumpAndSettle();

      for (final outcome in ['win', 'draw', 'loss']) {
        final option = find.byKey(ValueKey('what-if-outcome-$outcome'));
        final label = find.descendant(of: option, matching: find.byType(Text));
        final logo = find.byKey(ValueKey('what-if-outcome-logo-$outcome'));
        expect(label, findsOneWidget);
        expect(tester.getRect(label).center.dy,
            closeTo(tester.getRect(logo).center.dy, 0.1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 430.0]) {
    testWidgets('selected what-if bar keeps one color at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const teamColor = Color(0xFFA50044);

      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityWhatIfScreen(
          snapshot: _snapshot(),
          event: 'league_winner',
          teamPrimaryColor: teamColor,
        ),
      ));
      await tester.pumpAndSettle();

      Color barColor(String outcome) => (tester
              .widget<DecoratedBox>(
                  find.byKey(ValueKey('what-if-scenario-bar-$outcome')))
              .decoration as BoxDecoration)
          .color!;

      const outcomes = ['win', 'draw', 'loss'];
      expect({for (final outcome in outcomes) barColor(outcome)}.length, 3);
      for (final selected in outcomes) {
        await tester.tap(find.byKey(ValueKey('what-if-outcome-$selected')));
        await tester.pump();
        for (final outcome in outcomes) {
          expect(
              barColor(outcome),
              outcome == selected
                  ? teamColor
                  : teamColor.withValues(alpha: .18));
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('keeps a 100% line behind the Y-axis label background',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityScreen(
        teamId: 83,
        event: 'league_winner',
        initialSnapshot: _snapshot(
          firstPlayedRound: 0,
          firstLeagueProbability: 1,
          latestLeagueProbability: 1,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final chart = find.byKey(const ValueKey('probability-history-line-chart'));
    expect(tester.widget<LineChart>(chart).data.maxY, 100);
    expect(tester.widget<LineChart>(chart).data.lineBarsData.single.spots.first,
        const FlSpot(0, 100));
    final label = find.byKey(const ValueKey('probability-history-top-label'));
    expect(
        tester
            .widget<Text>(find.descendant(
              of: label,
              matching: find.byType(Text),
            ))
            .data,
        '100%');
    final mask =
        find.ancestor(of: label, matching: find.byType(ColoredBox)).first;
    expect(tester.widget<ColoredBox>(mask).color,
        app_style.AppColors.of(tester.element(mask)).cardBackground);
    final gutterMask =
        find.byKey(const ValueKey('probability-history-top-gutter-mask'));
    expect(tester.widget<ColoredBox>(gutterMask).color,
        app_style.AppColors.of(tester.element(gutterMask)).cardBackground);
    expect(tester.getSize(gutterMask).width, RoundChartVisuals.axisLineInset);
    final gridPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('probability-history-grid')),
        )
        .painter! as RoundChartGridPainter;
    expect(gridPainter.insetLineIndices, containsAll([0, 1]));
    final viewport = find.byKey(const ValueKey('probability-history-viewport'));
    await tester.scrollUntilVisible(
      viewport,
      200,
      scrollable: find.byWidgetPredicate((widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down),
    );
    await tester.pumpAndSettle();
    final initialViewport = tester.getRect(viewport);
    final initialChart = tester.getRect(chart);
    final initialLabel = tester.getRect(label);
    final gutter = tester.getRect(gutterMask);
    final plotClip =
        find.byKey(const ValueKey('probability-history-plot-clip'));
    expect(tester.widget<ClipRect>(plotClip).clipBehavior, Clip.hardEdge);
    final fixedClip = tester.getRect(plotClip);
    expect(fixedClip.left, initialViewport.left);
    expect(fixedClip.right, initialViewport.right);
    expect(gutter.left, initialViewport.left);
    expect(initialChart.left, lessThan(gutter.right));
    expect(gutter.bottom, greaterThanOrEqualTo(initialLabel.bottom));
    final handle = find.descendant(
      of: viewport,
      matching: find.byKey(const ValueKey('round-chart-selection-handle')),
    );
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(Offset(-initialViewport.width * 5 / 14, 0));
    await drag.up();
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<AnimatedSlide>(
              find.byKey(const ValueKey('probability-history-reveal-slide')),
            )
            .offset
            .dx,
        closeTo(
            RoundChartVisuals.axisLineInset / initialViewport.width, 0.001));
    expect(tester.getRect(viewport).left,
        closeTo(initialViewport.left + RoundChartVisuals.axisLineInset, 0.1));
    expect(tester.getRect(chart).left,
        closeTo(initialChart.left + RoundChartVisuals.axisLineInset, 0.1));
    expect(tester.getRect(chart).left, closeTo(gutter.right, 0.1));
    expect(tester.getRect(plotClip), fixedClip);
    expect(tester.getRect(label), initialLabel);
    expect(tester.getRect(handle).left + RoundChartSelectionHandle.tipInset,
        closeTo(tester.getRect(viewport).left, 0.1));
    expect(
        tester
            .getRect(find.byKey(const ValueKey('probability-history-tooltip')))
            .left,
        greaterThan(tester.getRect(mask).right));
    final returnDrag = await tester.startGesture(tester.getCenter(handle));
    await returnDrag.moveBy(Offset(initialViewport.width * 5 / 14, 0));
    await returnDrag.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(viewport).left, closeTo(initialViewport.left, 0.1));
    expect(tester.getRect(chart).left, closeTo(initialChart.left, 0.1));
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
    expect((historyData.minY, historyData.maxY), (0, 20));
    expect(
      tester
          .widget<Text>(find.descendant(
            of: find.byKey(const ValueKey('probability-history-middle-label')),
            matching: find.byType(Text),
          ))
          .data,
      '10%',
    );

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
      event: 'relegation_playoff',
      teamId: 83,
      unchanged: false,
      expected: '바르셀로나가 이기면 강등 플레이오프 확률이 4.0%p 내려가요. 지면 5.0%p 올라요.'
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
          lossProbability: testCase.unchanged ? 0.324 : 0.21,
          relegationEvent: testCase.event == 'relegation_playoff'
              ? 'relegation_playoff'
              : 'direct_relegation');
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
      expect(find.text('BAR 승'), findsOneWidget);
      expect(find.text('GET 승'), findsOneWidget);
      expect(find.text('무승부'), findsOneWidget);
      for (final label in ['BAR 승', 'GET 승', '무승부']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
            of: find.text(label), matching: find.byType(RichText)));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      final winOption = find.byKey(const ValueKey('what-if-outcome-win'));
      final teamCode = testCase.teamId == 83 ? 'BAR' : 'GET';
      expect(find.descendant(of: winOption, matching: find.text('$teamCode 승')),
          findsOneWidget);
      expect(find.descendant(of: winOption, matching: find.byType(Text)),
          findsOneWidget);
      await tester.tap(winOption);
      await tester.pump();
      await tester.scrollUntilVisible(find.text(testCase.expected), 200);
      expect(find.text(testCase.expected), findsOneWidget);
      if (testCase.event == 'relegation_playoff') {
        expect(find.text('강등 플레이오프 확률'), findsOneWidget);
      }
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
    double lossProbability = 0.21,
    int firstPlayedRound = 4,
    double firstLeagueProbability = 0.26,
    double latestLeagueProbability = 0.324,
    String relegationEvent = 'direct_relegation'}) {
  final currentCard = TeamProbabilityCard(
    event: 'league_winner',
    competitionId: 564,
    category: 'TITLE',
    probability: latestLeagueProbability,
    changePercentagePoints: 2.44,
    entropy: 0.9,
  );
  final relegationCard = TeamProbabilityCard(
    event: relegationEvent,
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
      changePoints: 1.26,
    ),
    comparison: TeamProbabilityComparison(
      available: true,
      asOf: DateTime.utc(2026, 9, 11),
    ),
    cards: [currentCard, relegationCard],
    history: [
      TeamProbabilityHistoryPoint(
        asOf: DateTime.utc(2026, 9, 11),
        played: firstPlayedRound,
        events: [
          TeamProbabilityCard(
            event: 'league_winner',
            competitionId: 564,
            category: 'TITLE',
            probability: firstLeagueProbability,
            changePercentagePoints: null,
            entropy: null,
          ),
        ],
        expectedPoints: 80.8,
      ),
      TeamProbabilityHistoryPoint(
        asOf: DateTime.utc(2026, 9, 18),
        played: 5,
        events: [currentCard, relegationCard],
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
        _scenario('win', winProbability, relegationEvent),
        _scenario('draw', 0.29, relegationEvent),
        _scenario('loss', lossProbability, relegationEvent),
      ],
    ),
  );
}

TeamProbabilityWhatIfScenario _scenario(
    String outcome, double probability, String relegationEvent) {
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
        event: relegationEvent,
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
