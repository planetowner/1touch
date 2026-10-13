import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/screens/TeamProbabilityScreen.dart';
import 'package:onetouch/screens/team_probability_what_if_screen.dart';

import 'support/screen_pixels.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('European what-if shows its next European fixture at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousCompetitions = footballCatalog.competitions.value;
      footballCatalog.competitions.value = const [
        Competition(
            competitionId: 2, name: 'Champions League', shortCode: 'UCL'),
      ];
      addTearDown(
          () => footballCatalog.competitions.value = previousCompetitions);
      final kickoff = DateTime.utc(2027, 3, 12, 18);
      Fixture match(int id, int competitionId, DateTime date) => Fixture(
            fixtureId: id,
            seasonId: 11,
            competitionId: competitionId,
            homeTeamId: 83,
            awayTeamId: id,
            awayTeamName: 'Opponent $id',
            competitionType: competitionId == 2
                ? CompetitionType.europe
                : CompetitionType.league,
            roundName: competitionId == 2 ? 'Round of 16' : 'Round 27',
            leg: competitionId == 2 ? '2/2' : null,
            status: FixtureStatus.upcoming,
            startingAt: date.toIso8601String(),
          );
      final repository = MockFixtureRepository(fixtures: [
        match(90, 564, kickoff.subtract(const Duration(days: 3))),
        match(91, 2, kickoff),
        match(92, 2, kickoff.add(const Duration(days: 8))),
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'ucl_winner',
          initialSnapshot: _europeanSnapshot(withWhatIf: true),
          repository: _RefreshProbabilityRepository(
              _europeanSnapshot(withWhatIf: true)),
          fixtureRepository: repository,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('probability-what-if-button')),
        300,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );
      await tester
          .tap(find.byKey(const ValueKey('probability-what-if-button')));
      await tester.pumpAndSettle();

      expect(find.byType(TeamProbabilityWhatIfScreen), findsOneWidget);
      for (final teamId in [83, 91]) {
        final name = find.byKey(ValueKey('what-if-team-name-$teamId'));
        expect(name, findsOneWidget);
        final label = tester.widget<Text>(name);
        expect(label.maxLines, 1);
        expect(label.overflow, TextOverflow.ellipsis);
      }
      expect(find.text('Round of 16'), findsOneWidget);
      expect(find.text('2nd Leg'), findsOneWidget);
      expect(tester.getRect(find.text('Round of 16')).bottom,
          lessThanOrEqualTo(tester.getRect(find.text('2nd Leg')).top));
      expect(find.text('Opponent 91'), findsOneWidget);
      expect(find.text('Round 27'), findsNothing);
      expect(
          find.byKey(const ValueKey('what-if-outcome-draw')), findsOneWidget);
      final drawHomeLogo =
          tester.getRect(find.byKey(const ValueKey('what-if-draw-home-logo')));
      final drawAwayLogo =
          tester.getRect(find.byKey(const ValueKey('what-if-draw-away-logo')));
      expect(
          find.byKey(const ValueKey('what-if-draw-home-clip')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('what-if-draw-away-clip')), findsOneWidget);
      expect(drawHomeLogo.overlaps(drawAwayLogo), isTrue);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('what-if-scenario-chart')), 200);
      expect(find.text('UCL WINNER PROBABILITY'), findsOneWidget);
      expect(
          tester
                  .getRect(find.byKey(const ValueKey('what-if-scenario-chart')))
                  .top -
              tester.getRect(find.text('UCL WINNER PROBABILITY')).bottom,
          closeTo(16, 0.1));
      expect(find.byKey(const ValueKey('what-if-scenario-bar-win')),
          findsOneWidget);
      for (final outcome in ['win', 'loss']) {
        expect(
            tester
                    .getRect(
                        find.byKey(ValueKey('what-if-scenario-bar-$outcome')))
                    .top -
                tester
                    .getRect(
                        find.byKey(ValueKey('what-if-scenario-value-$outcome')))
                    .bottom,
            closeTo(8, 0.1));
      }
      expect(find.byKey(const ValueKey('what-if-scenario-bar-draw')),
          findsNothing);
      expect(find.text('–'), findsWidgets);
      final explanation =
          find.byKey(const ValueKey('what-if-scenario-explanation'));
      await tester.scrollUntilVisible(explanation, 100);
      expect(explanation, findsOneWidget);
      expect(
          tester.getRect(explanation).top -
              tester
                  .getRect(find.byKey(const ValueKey('what-if-scenario-chart')))
                  .bottom,
          closeTo(16, 1));
      expect(find.textContaining('increases by 30.0 percentage points'),
          findsOneWidget);
      expect(find.textContaining('decreases by 20.0 percentage points'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final round in ['Final', 'Semi-final']) {
      testWidgets('$round what-if draw rule at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousCompetitions = footballCatalog.competitions.value;
        footballCatalog.competitions.value = const [
          Competition(
              competitionId: 2, name: 'Champions League', shortCode: 'UCL'),
        ];
        addTearDown(
            () => footballCatalog.competitions.value = previousCompetitions);

        await tester.pumpWidget(MaterialApp(
          theme: app_style.darktheme,
          home: TeamProbabilityWhatIfScreen(
            snapshot: _europeanSnapshot(
                withWhatIf: true, finalWhatIf: round == 'Final'),
            event: 'ucl_winner',
            teamPrimaryColor: const Color(0xFFA50044),
            europeanFixture: Fixture(
              fixtureId: 91,
              seasonId: 11,
              competitionId: 2,
              homeTeamId: 83,
              awayTeamId: 91,
              competitionType: CompetitionType.europe,
              roundName: round,
              leg: round == 'Final' ? null : '2/2',
              legNumber: round == 'Final' ? null : 2,
              status: FixtureStatus.upcoming,
              stateName: 'Final',
              startingAt: DateTime.utc(2027, 5, 12).toIso8601String(),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const ValueKey('what-if-outcome-win')), findsOneWidget);
        expect(
            find.byKey(const ValueKey('what-if-outcome-loss')), findsOneWidget);
        expect(find.byKey(const ValueKey('what-if-outcome-draw')),
            round == 'Final' ? findsNothing : findsOneWidget);
        expect(find.text(round), findsOneWidget);
        expect(find.text('2nd Leg'),
            round == 'Final' ? findsNothing : findsOneWidget);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('what-if-scenario-chart')), 200);
        expect(find.byKey(const ValueKey('what-if-scenario-bar-win')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('what-if-scenario-bar-draw')),
            findsNothing);
        expect(find.text('If draw'),
            round == 'Final' ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('European what-if does not show another fixture prediction',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityWhatIfScreen(
        snapshot: _europeanSnapshot(withWhatIf: true),
        event: 'ucl_winner',
        teamPrimaryColor: const Color(0xFFA50044),
        europeanFixture: Fixture(
          fixtureId: 92,
          seasonId: 11,
          competitionId: 2,
          homeTeamId: 83,
          awayTeamId: 92,
          competitionType: CompetitionType.europe,
          roundName: 'Quarter-finals',
          status: FixtureStatus.upcoming,
          startingAt: DateTime.utc(2027, 4, 12).toIso8601String(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Not ready yet'), 200);
    expect(find.text('UCL WINNER PROBABILITY'), findsOneWidget);
    expect(find.byKey(const ValueKey('what-if-scenario-chart')), findsNothing);
    expect(find.text('Not ready yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('European what-if omits explanation without both changes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityWhatIfScreen(
        snapshot: _europeanSnapshot(withWhatIf: true, missingLossChange: true),
        event: 'ucl_winner',
        teamPrimaryColor: const Color(0xFFA50044),
        europeanFixture: Fixture(
          fixtureId: 91,
          seasonId: 11,
          competitionId: 2,
          homeTeamId: 83,
          awayTeamId: 91,
          competitionType: CompetitionType.europe,
          roundName: 'Round of 16',
          status: FixtureStatus.upcoming,
          startingAt: DateTime.utc(2027, 3, 12).toIso8601String(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('what-if-scenario-chart')), 100);
    expect(
        find.byKey(const ValueKey('what-if-scenario-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('what-if-scenario-explanation')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

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
                ? '강등 PO 확률'
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
      expect(find.byKey(const ValueKey('european-probability-history-info')),
          findsNothing);
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

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('European probability history help fits at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = _europeanSnapshot();
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'ucl_winner',
          initialSnapshot: snapshot,
          repository: _RefreshProbabilityRepository(snapshot),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('european-stage-history-card')),
        200,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );

      final help =
          find.byKey(const ValueKey('european-probability-history-info'));
      expect(help, findsOneWidget);
      expect(tester.getSize(help), const Size(14, 14));
      expect(
          tester.getTopLeft(help).dx -
              tester.getTopRight(find.text('PROBABILITY HISTORY')).dx,
          4);
      await tester.dragFrom(const Offset(120, 180), const Offset(0, 160));
      await tester.pumpAndSettle();
      await tester.tap(help);
      await tester.pumpAndSettle();

      expect(
          find.text(
              "Tracks how your team's chance of winning the competition changes over time. Winning a first leg raises it, and once the tie is decided, that probability carries into the next round"),
          findsOneWidget);
      final popup = find.byKey(const ValueKey('app-info-popup'));
      final content = find.byKey(const ValueKey('app-info-content'));
      expect(tester.widget<Padding>(content).padding, const EdgeInsets.all(24));
      await tester.tap(find.byKey(const ValueKey('app-info-close')));
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('European stage axis snaps to six fixed stops at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final european = _europeanSnapshot();
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: european.teamId,
          event: 'ucl_winner',
          initialSnapshot: european,
          repository: _RefreshProbabilityRepository(european),
        ),
      ));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('european-stage-history-card'));
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
      final stages = ['League', 'PO', 'R16', 'QF', 'SF', 'Final'];
      for (final stage in stages) {
        expect(find.byKey(ValueKey('european-stage-$stage')), findsOneWidget);
      }
      final stageRects = [
        for (final stage in stages)
          tester.getRect(find.byKey(ValueKey('european-stage-$stage'))),
      ];
      final gaps = [
        for (var index = 0; index < stageRects.length - 1; index++)
          stageRects[index + 1].left - stageRects[index].right,
      ];
      for (final gap in gaps.skip(1)) {
        expect(gap, closeTo(gaps.first, 0.1));
      }
      expect(
          stageRects.first.left, closeTo(tester.getRect(card).left + 16, 0.1));
      expect(
          stageRects.last.right, closeTo(tester.getRect(card).right - 16, 0.1));
      expect(find.byKey(const ValueKey('european-stage-history-line')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('european-stage-top-label')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('european-stage-middle-label')),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('european-stage-tooltip')),
            matching: find.text('32%'),
          ),
          findsOneWidget);
      expect(find.byKey(const ValueKey('probability-history-line-chart')),
          findsNothing);
      expect(find.byKey(const ValueKey('probability-history-tooltip')),
          findsNothing);

      final handle = find.byKey(const ValueKey('round-chart-selection-handle'));
      final round16 = find.byKey(const ValueKey('european-stage-R16'));
      final finalStage = find.byKey(const ValueKey('european-stage-Final'));
      expect(tester.getCenter(handle).dx,
          closeTo(tester.getCenter(round16).dx, 0.3));
      await tester.drag(
          handle,
          Offset(
            tester.getCenter(finalStage).dx - tester.getCenter(handle).dx,
            0,
          ));
      await tester.pumpAndSettle();
      expect(tester.getCenter(handle).dx,
          closeTo(tester.getCenter(round16).dx, 0.3));
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('european-stage-tooltip')),
            matching: find.text('32%'),
          ),
          findsOneWidget);
      await tester.tap(finalStage);
      await tester.pumpAndSettle();
      expect(tester.getCenter(handle).dx,
          closeTo(tester.getCenter(round16).dx, 0.3));
      await tester.tap(find.byKey(const ValueKey('european-stage-R16')));
      await tester.pumpAndSettle();
      expect(
          tester.getCenter(handle).dx,
          closeTo(
              tester
                  .getCenter(find.byKey(const ValueKey('european-stage-R16')))
                  .dx,
              0.3));
      await tester.tap(find.byKey(const ValueKey('european-stage-League')));
      await tester.pumpAndSettle();
      expect(
          tester.getCenter(handle).dx,
          closeTo(
              tester
                  .getCenter(
                      find.byKey(const ValueKey('european-stage-League')))
                  .dx,
              0.3));
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('european-stage-tooltip')),
            matching: find.text('18%'),
          ),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final theme in [
      app_style.darktheme,
      app_style.lightThemeForLocale(const Locale('en')),
    ]) {
      testWidgets(
          'European League-only axis and tooltip fit at $size ${theme.brightness}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final snapshot = _europeanSnapshot(leagueOnlyHistory: true);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: TeamProbabilityScreen(
            teamId: 83,
            event: 'ucl_winner',
            initialSnapshot: snapshot,
            repository: _RefreshProbabilityRepository(snapshot),
          ),
        ));
        await tester.pumpAndSettle();
        final chart = find.byKey(const ValueKey('european-stage-history-card'));
        await tester.scrollUntilVisible(
          chart,
          200,
          scrollable: find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down),
        );

        expect(chart, findsOneWidget);
        expect(find.byKey(const ValueKey('european-stage-history-line')),
            findsOneWidget);
        final gridPainter = tester
            .widget<CustomPaint>(
                find.byKey(const ValueKey('european-stage-grid')))
            .painter! as RoundChartGridPainter;
        expect(gridPainter.insetLineIndices, contains(0));
        expect(
            gridPainter.insetLineIndices
                .any((index) => index == 5 || index == 6),
            isTrue);
        expect(
            find.descendant(
              of: find.byKey(const ValueKey('european-stage-tooltip')),
              matching: find.text('18%'),
            ),
            findsOneWidget);
        expect(
            find.descendant(
              of: find.byKey(const ValueKey('european-stage-tooltip')),
              matching: find.text('League'),
            ),
            findsOneWidget);
        final topLabel = find.byKey(const ValueKey('european-stage-top-label'));
        final middleLabel =
            find.byKey(const ValueKey('european-stage-middle-label'));
        expect(find.descendant(of: topLabel, matching: find.text('20%')),
            findsOneWidget);
        expect(find.descendant(of: middleLabel, matching: find.text('10%')),
            findsOneWidget);
        final tooltip = tester
            .getRect(find.byKey(const ValueKey('european-stage-tooltip')));
        final cardRect = tester.getRect(chart);
        expect(tooltip.left, greaterThanOrEqualTo(cardRect.left));
        expect(tooltip.right, lessThanOrEqualTo(cardRect.right));
        final league = find.descendant(
          of: find.byKey(const ValueKey('european-stage-League')),
          matching: find.text('League'),
        );
        final finalStage = find.descendant(
          of: find.byKey(const ValueKey('european-stage-Final')),
          matching: find.text('Final'),
        );
        expect(tester.getRect(league).left,
            greaterThanOrEqualTo(cardRect.left + 16));
        expect(tester.getRect(finalStage).right,
            lessThanOrEqualTo(cardRect.right - 16));
        for (final label in [league, finalStage]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(
          tester
              .getCenter(
                  find.byKey(const ValueKey('round-chart-selection-handle')))
              .dx,
          closeTo(
              tester
                  .getCenter(
                      find.byKey(const ValueKey('european-stage-League')))
                  .dx,
              0.3),
        );
        final handle =
            find.byKey(const ValueKey('round-chart-selection-handle'));
        await tester.ensureVisible(handle);
        await tester.pumpAndSettle();
        await tester.drag(
            handle,
            Offset(
                tester.getCenter(finalStage).dx - tester.getCenter(handle).dx,
                0));
        await tester.pumpAndSettle();
        expect(tester.getCenter(handle).dx,
            closeTo(tester.getCenter(league).dx, 0.3));
        await tester.tap(finalStage);
        await tester.pumpAndSettle();
        expect(tester.getCenter(handle).dx,
            closeTo(tester.getCenter(league).dx, 0.3));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final theme in [
    app_style.darktheme,
    app_style.lightThemeForLocale(const Locale('en')),
  ]) {
    testWidgets('European point covers its guide in ${theme.brightness}',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const pointColor = Color(0xFFD82457);
      final snapshot = _europeanSnapshot();
      const boundaryKey = ValueKey('european-history-pixels');
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: boundaryKey,
          child: TeamProbabilityScreen(
            teamId: snapshot.teamId,
            event: 'ucl_winner',
            teamPrimaryColor: pointColor,
            initialSnapshot: snapshot,
            repository: _RefreshProbabilityRepository(snapshot),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final guide = find.byKey(const ValueKey('european-stage-selector-line'));
      await tester.scrollUntilVisible(
        guide,
        200,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );
      await tester.pumpAndSettle();
      final guideRect = tester.getRect(guide);
      final x = tester
          .getCenter(find.byKey(const ValueKey('round-chart-selection-handle')))
          .dx;
      final pointY = guideRect.top + guideRect.height * (1 - 32 / 40);
      final pixels = await screenPixels(
        tester,
        find.byKey(boundaryKey),
        [Offset(x, guideRect.top + 3), Offset(x, pointY)],
      );

      expect(
          pixels.first.r,
          theme.brightness == Brightness.dark
              ? greaterThan(0.7)
              : lessThan(0.4));
      expect(pixels.last, pointColor);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('European 100% label stays on one line at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final snapshot = _europeanSnapshot(unresolvedHundred: true);
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'ucl_winner',
          initialSnapshot: snapshot,
          repository: _RefreshProbabilityRepository(snapshot),
        ),
      ));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('european-how-far-R16'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );
      final label = find.descendant(of: row, matching: find.text('100%'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );

      expect(label, findsOneWidget);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.getRect(label).width,
        paragraph.getMaxIntrinsicWidth(double.infinity).ceilToDouble(),
      );
      expect(
        tester.getRect(label).left -
            tester
                .getRect(find.byKey(const ValueKey('european-how-far-bar-R16')))
                .right,
        closeTo(12, 0.1),
      );
      expect(tester.getRect(label).right, closeTo(size.width - 24, 0.1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('European API progression and contenders fit at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: TeamProbabilityScreen(
          teamId: 83,
          event: 'ucl_winner',
          initialSnapshot: _europeanSnapshot(),
          repository: _RefreshProbabilityRepository(_europeanSnapshot()),
          teamPrimaryColor: const Color(0xFFD82457),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('european-how-far')),
        200,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROJECTED FINAL POSITION'), findsNothing);
      expect(
          find.byKey(const ValueKey('projected-final-position')), findsNothing);
      expect(find.text('PROJECTED POINTS'), findsNothing);
      expect(find.text('TITLE CONTENDERS'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('title-contenders-card')),
        200,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );
      expect(
          find.byKey(const ValueKey('title-contenders-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('title-contenders-rank-movement')),
          findsOneWidget);
      final titleCard = find.byKey(const ValueKey('title-contenders-card'));
      final rankMovement =
          find.byKey(const ValueKey('title-contenders-rank-movement'));
      final rankText = find.text('#2');
      expect(tester.getRect(rankText).top,
          closeTo(tester.getRect(titleCard).top + 24, 0.1));
      expect(tester.widget<Text>(rankText).style!.height, 0.9);
      expect(
        tester.getRect(find.text('in odds to win title')).top -
            tester.getRect(rankText).bottom,
        closeTo(12, 0.1),
      );
      expect(
        tester.getCenter(rankMovement).dy,
        closeTo(tester.getCenter(find.text('#2')).dy, 1),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('title-contender-row-90')))
            .left,
        closeTo(tester.getRect(titleCard).left + 24, 0.1),
      );
      expect(
        tester
                .getRect(find.byKey(const ValueKey('title-contender-row-83')))
                .top -
            tester
                .getRect(find.byKey(const ValueKey('title-contender-row-90')))
                .bottom,
        closeTo(16, 0.1),
      );
      expect(find.text('AAA'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(
        tester
                .getRect(
                    find.byKey(const ValueKey('probability-what-if-button')))
                .top -
            tester.getRect(titleCard).bottom,
        closeTo(48, 0.1),
      );
      const teamIds = [90, 83, 91, 92, 93];
      const probabilities = [0.50, 0.32, 0.10, 0.05, 0.03];
      for (var rank = 1; rank <= 5; rank++) {
        final row =
            find.byKey(ValueKey('title-contender-row-${teamIds[rank - 1]}'));
        expect(row, findsOneWidget);
        expect(
          find.descendant(
            of: row,
            matching: find.byWidgetPredicate((widget) =>
                widget is Text &&
                RegExp(r'^[A-Z]{3}$').hasMatch(widget.data ?? '')),
          ),
          findsOneWidget,
        );
        final fill =
            find.byKey(ValueKey('title-contender-fill-${teamIds[rank - 1]}'));
        expect(fill, findsOneWidget);
        final track =
            find.ancestor(of: fill, matching: find.byType(ClipRRect)).first;
        expect(tester.getSize(fill).height, 10);
        expect(
          tester.getSize(fill).width,
          closeTo(tester.getSize(track).width * probabilities[rank - 1], 0.1),
        );
        expect(
          tester
              .widget<Opacity>(
                find.ancestor(of: fill, matching: find.byType(Opacity)).first,
              )
              .opacity,
          rank == 2 ? 1 : 0.5,
        );
      }
      for (final stage in ['WINNER', 'FINAL', 'SF', 'QF', 'R16', 'PO']) {
        expect(find.byKey(ValueKey('european-how-far-$stage')), findsOneWidget);
      }
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('european-how-far-WINNER')),
            matching: find.text('32%'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('european-how-far-FINAL')),
            matching: find.text('40%'),
          ),
          findsOneWidget);
      final poBar = find.byKey(const ValueKey('european-how-far-bar-PO'));
      expect(tester.getSize(poBar).height, 10);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: poBar, matching: find.byType(Opacity)).first,
            )
            .opacity,
        0.5,
      );
      final poCheck = find.descendant(
        of: find.byKey(const ValueKey('european-how-far-PO')),
        matching: find.byIcon(Icons.check_circle),
      );
      expect(poCheck, findsOneWidget);
      final checkColumn = find
          .ancestor(
            of: poCheck,
            matching: find.byType(SizedBox),
          )
          .first;
      expect(tester.getRect(poCheck).right,
          closeTo(tester.getRect(checkColumn).right, 0.1));
      expect(tester.takeException(), isNull);
    });
  }

  test('title contenders keep top five and clamp at the bottom', () {
    final ranked = List.generate(15, (index) => index + 1);
    expect(titleContendersWindow(ranked, 1), [1, 2, 3, 4, 5]);
    expect(titleContendersWindow(ranked, 7), [6, 7, 8, 9, 10]);
    expect(titleContendersWindow(ranked, 13), [11, 12, 13, 14, 15]);
    expect(titleContendersWindow(ranked, 14), [11, 12, 13, 14, 15]);
  });

  testWidgets('European detail refreshes an old cached snapshot',
      (tester) async {
    final repository = _RefreshProbabilityRepository(_europeanSnapshot());
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityScreen(
        teamId: 83,
        event: 'ucl_winner',
        initialSnapshot: _europeanSnapshot(includeDetail: false),
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();
    expect(repository.lastForceRefresh, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('title-contenders-card')),
      200,
      scrollable: find.byWidgetPredicate((widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down),
    );
    expect(find.byKey(const ValueKey('title-contenders-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('European detail refreshes even when cached detail exists',
      (tester) async {
    final repository = _RefreshProbabilityRepository(_europeanSnapshot());
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityScreen(
        teamId: 83,
        event: 'ucl_winner',
        initialSnapshot: _europeanSnapshot(),
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 1);
    expect(repository.lastForceRefresh, isTrue);
    expect(find.byKey(const ValueKey('team-probability-detail-retry')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('European detail does not retain cached data missing from API',
      (tester) async {
    final repository =
        _RefreshProbabilityRepository(_europeanSnapshot(includeDetail: false));
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityScreen(
        teamId: 83,
        event: 'ucl_winner',
        initialSnapshot: _europeanSnapshot(),
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(repository.lastForceRefresh, isTrue);
    expect(find.byKey(const ValueKey('title-contenders-card')), findsNothing);
    expect(find.byKey(const ValueKey('team-probability-detail-retry')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('European refresh failure shows retry instead of cached detail',
      (tester) async {
    final repository = _RefreshProbabilityRepository(_europeanSnapshot())
      ..error = StateError('Refresh failed');
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: TeamProbabilityScreen(
        teamId: 83,
        event: 'ucl_winner',
        initialSnapshot: _europeanSnapshot(),
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Prediction unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('team-probability-detail-retry')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('title-contenders-card')), findsNothing);
    expect(
        find.byKey(const ValueKey('probability-what-if-button')), findsNothing);

    repository.error = null;
    await tester
        .tap(find.byKey(const ValueKey('team-probability-detail-retry')));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(repository.lastForceRefresh, isTrue);
    expect(find.byKey(const ValueKey('team-probability-detail-retry')),
        findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('probability-what-if-button')),
      300,
      scrollable: find.byWidgetPredicate((widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down),
    );
    expect(find.byKey(const ValueKey('probability-what-if-button')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('iOS chart drag stays on probability page at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final snapshot = _europeanSnapshot();
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme.copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TeamProbabilityScreen(
                  teamId: snapshot.teamId,
                  event: 'ucl_winner',
                  initialSnapshot: snapshot,
                  repository: _RefreshProbabilityRepository(snapshot),
                ),
              )),
              child: const Text('Open probability'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open probability'));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('european-stage-history-card'));
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

      final handle = find.byKey(const ValueKey('round-chart-selection-handle'));
      expect(ModalRoute.of(tester.element(handle))!.popGestureEnabled, isTrue);
      await tester.drag(handle, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(find.byType(TeamProbabilityScreen), findsOneWidget);
      expect(
          tester.getCenter(handle).dx,
          greaterThan(tester
              .getCenter(find.byKey(const ValueKey('european-stage-PO')))
              .dx));

      await tester.dragFrom(
        Offset(8, tester.getCenter(card).dy),
        Offset(size.width * 0.75, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TeamProbabilityScreen), findsNothing);
      expect(find.text('Open probability'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('what-if back icon starts 24px from the left at $size',
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
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Round 6'), findsOneWidget);
      expect(find.textContaining('La Liga'), findsNothing);
      expect(find.textContaining('Leg'), findsNothing);
      final icon = find.descendant(
        of: find.byKey(const ValueKey('what-if-back-button')),
        matching: find.byIcon(Icons.arrow_back_ios_new),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('what-if-back-button'))).left,
        closeTo(24, 0.1),
      );
      expect(tester.getRect(icon).left, closeTo(24, 0.1));
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
    final backButton = find.byKey(const ValueKey('probability-back-button'));
    final backIcon = find.descendant(
      of: backButton,
      matching: find.byIcon(Icons.arrow_back_ios_new),
    );
    expect(tester.getTopLeft(backButton).dx, 24);
    expect(tester.getTopLeft(backIcon).dx, 24);
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
      final overlapsLabel = (lineY >= topMask.top && lineY < topMask.bottom) ||
          (lineY > middleMask.top && lineY < middleMask.bottom);
      expect(gridPainter.insetLineIndices.contains(index), overlapsLabel);
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
    expect(selectionPainter.color, teamPrimaryColor);
    expect(selectionPainter.guideColor, app_style.AppPalette.white);
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final whatIfButton =
        find.byKey(const ValueKey('probability-what-if-button'));
    final buttonTop = tester.getRect(whatIfButton).top;
    expect(
      buttonTop -
          tester
              .getRect(find.byKey(const ValueKey('projected-points-card')))
              .bottom,
      closeTo(48, 0.1),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(tester.getRect(whatIfButton).top, greaterThan(buttonTop));
    await tester.drag(find.byType(ListView).first, const Offset(0, -40));
    await tester.pumpAndSettle();
    await tester.tap(whatIfButton);
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
      expected: '바르셀로나가 이기면 강등 PO 확률이 4.0%p 내려가요. 지면 5.0%p 올라요.'
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
      expect(find.text('6R'), findsOneWidget);
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
        expect(find.text('강등 PO 확률'), findsOneWidget);
      }
      for (final label in ['이기면', '비기면', '지면']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

TeamProbabilitySnapshot _europeanSnapshot({
  bool includeDetail = true,
  bool unresolvedHundred = false,
  bool leagueOnlyHistory = false,
  bool withWhatIf = false,
  bool finalWhatIf = false,
  bool missingLossChange = false,
}) {
  final base = _snapshot();
  return TeamProbabilitySnapshot(
    teamId: base.teamId,
    teamName: base.teamName,
    competitionId: base.competitionId,
    seasonId: base.seasonId,
    seasonName: base.seasonName,
    asOf: base.asOf,
    maximumPoints: base.maximumPoints,
    positions: base.positions,
    projectedPoints: base.projectedPoints,
    comparison: base.comparison,
    cards: [
      ...base.cards,
      const TeamProbabilityCard(
        event: 'ucl_winner',
        competitionId: 2,
        category: 'TITLE',
        probability: 0.32,
        changePercentagePoints: null,
        entropy: null,
      ),
    ],
    history: base.history,
    pendingOutcomes: base.pendingOutcomes,
    europeanTitle: includeDetail
        ? EuropeanTitleProbability(
            history: leagueOnlyHistory
                ? const [
                    EuropeanStageHistoryPoint(
                        stageKey: 'league', probability: 0.18),
                  ]
                : const [
                    EuropeanStageHistoryPoint(
                        stageKey: 'league', probability: 0.18),
                    EuropeanStageHistoryPoint(
                        stageKey: 'round16', probability: 0.32),
                  ],
            stageProbabilities: [
              const EuropeanStageProbability(
                stageKey: 'winner',
                probability: 0.32,
                resolution: ProbabilityResolution.unresolved,
              ),
              const EuropeanStageProbability(
                stageKey: 'final',
                probability: 0.40,
                resolution: ProbabilityResolution.unresolved,
              ),
              const EuropeanStageProbability(
                stageKey: 'semifinal',
                probability: 0.50,
                resolution: ProbabilityResolution.unresolved,
              ),
              const EuropeanStageProbability(
                stageKey: 'quarterfinal',
                probability: 0.60,
                resolution: ProbabilityResolution.unresolved,
              ),
              EuropeanStageProbability(
                stageKey: 'round16',
                probability: 1,
                resolution: unresolvedHundred
                    ? ProbabilityResolution.unresolved
                    : ProbabilityResolution.certain,
              ),
              const EuropeanStageProbability(
                stageKey: 'playoff',
                probability: 1,
                resolution: ProbabilityResolution.certain,
              ),
            ],
            titleContenders: TitleContenders(
              rank: 2,
              rankChange: 1,
              teams: const [
                TitleContender(
                  teamId: 90,
                  teamName: 'Real Madrid',
                  rank: 1,
                  probability: 0.50,
                ),
                TitleContender(
                  teamId: 83,
                  teamName: 'FC Barcelona',
                  rank: 2,
                  probability: 0.32,
                ),
                TitleContender(
                  teamId: 91,
                  teamName: 'Bayern Munich',
                  rank: 3,
                  probability: 0.10,
                ),
                TitleContender(
                  teamId: 92,
                  teamName: 'Paris Saint-Germain',
                  rank: 4,
                  probability: 0.05,
                ),
                TitleContender(
                  teamId: 93,
                  teamName: 'Arsenal',
                  rank: 5,
                  probability: 0.03,
                ),
              ],
            ),
            whatIf: withWhatIf
                ? EuropeanWhatIf(
                    fixtureId: 91,
                    scenarios: [
                      const EuropeanWhatIfScenario(
                        outcome: 'win',
                        probability: 0.62,
                        changePercentagePoints: 30,
                      ),
                      if (!finalWhatIf)
                        const EuropeanWhatIfScenario(
                          outcome: 'draw',
                          probability: null,
                          changePercentagePoints: null,
                        ),
                      EuropeanWhatIfScenario(
                        outcome: 'loss',
                        probability: 0.12,
                        changePercentagePoints: missingLossChange ? null : -20,
                      ),
                    ],
                  )
                : null,
          )
        : null,
  );
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

class _RefreshProbabilityRepository implements TeamProbabilityRepository {
  _RefreshProbabilityRepository(this.snapshot);

  final TeamProbabilitySnapshot snapshot;
  bool? lastForceRefresh;
  int loadCount = 0;
  Object? error;

  @override
  ValueListenable<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      get cachedSnapshots => ValueNotifier(const {});

  @override
  TeamProbabilitySnapshot? cachedForTeam(int teamId, {int? seasonId}) => null;

  @override
  Future<TeamProbabilitySnapshot> loadForTeam(
    int teamId, {
    bool forceRefresh = false,
    int? seasonId,
  }) async {
    loadCount++;
    lastForceRefresh = forceRefresh;
    if (error != null) throw error!;
    return snapshot;
  }
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
