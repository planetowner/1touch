import 'support/app_catalog.dart';
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/current_form/mock/mock_current_form_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Analysis.dart';

void main() {
  setUpAppCatalog();
  Widget buildSubject({
    required int? teamId,
    required CurrentFormRepository repository,
    ThemeData? theme,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      theme: theme ?? whitetheme,
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CurrentFormSection(
            team: teamId == null
                ? null
                : TeamOverview(
                    id: teamId,
                    name: 'Team $teamId',
                    shortName: 'T$teamId',
                    imagePath: '',
                  ),
            repository: repository,
          ),
        ),
      ),
    );
  }

  void useScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows only current points by default at compact width',
      (tester) async {
    useScreen(tester, const Size(320, 568));
    final queries = <CurrentFormComparisonQuery>[];
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => _optionsForTeam(1),
      comparisonLoader: (query) async {
        queries.add(query);
        return _comparisonFor(query, comparisonShortCode: 'PREV');
      },
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('analysis-current-form-section')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 32, 24, 0),
    );
    expect(queries, hasLength(1));
    expect(queries.single.seasonId, 200);
    expect(queries.single.compareTeamId, 1);
    expect(queries.single.compareSeasonId, 200);
    expect(find.text('24/25 PREV'), findsNothing);
    final chartCard = tester.widget<Container>(
      find.byKey(const ValueKey('analysis-current-form-chart-card')),
    );
    expect(
      (chartCard.decoration as BoxDecoration).boxShadow,
      lightModeCardShadows,
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(1));
    expect(chart.data.lineBarsData.first.color, const Color(0xFFD82457));
    final pointsLabel = find.byKey(
      const ValueKey('analysis-current-form-points-label'),
    );
    expect(tester.widget<RotatedBox>(pointsLabel).quarterTurns, 1);
    final chartCardRect = tester.getRect(
      find.byKey(const ValueKey('analysis-current-form-chart-card')),
    );
    final pointsLabelRect = tester.getRect(pointsLabel);
    expect(pointsLabelRect.left - chartCardRect.left, 16);
    expect(pointsLabelRect.top - chartCardRect.top, 16);
    expect(
      tester
              .getTopLeft(find
                  .byKey(const ValueKey('analysis-current-form-round-label')))
              .dy -
          tester
              .getBottomLeft(
                  find.byKey(const ValueKey('analysis-current-form-grid')))
              .dy,
      12,
    );
    final filter = find.byKey(const ValueKey('analysis-form-filter'));
    expect(filter, findsOneWidget);
    expect(tester.getSize(filter).width, 165);
    expect(
      find.descendant(of: filter, matching: find.text('SEASON')),
      findsOneWidget,
    );
    final legend = find.byKey(const ValueKey('analysis-current-form-legend'));
    expect(find.descendant(of: legend, matching: find.text('MY TEAM')),
        findsOneWidget);
    expect(find.descendant(of: legend, matching: find.textContaining('PREV')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads an exact cross-team option selected from the global list',
      (tester) async {
    final queries = <CurrentFormComparisonQuery>[];
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => _optionsForTeam(1),
      comparisonLoader: (query) async {
        queries.add(query);
        return _comparisonFor(
          query,
          comparisonShortCode: query.compareTeamId == 2 ? 'BETA' : 'PREV',
        );
      },
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();

    await _chooseCurrentForm(tester, seasonId: 200, teamId: 2);

    expect(queries, hasLength(2));
    expect(queries.last.seasonId, 200);
    expect(queries.last.compareTeamId, 2);
    expect(queries.last.compareSeasonId, 200);
    expect(find.text('25/26 BETA'), findsOneWidget);
  });

  testWidgets('groups Big Five teams by season name across league season IDs',
      (tester) async {
    final queries = <CurrentFormComparisonQuery>[];
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => [
        _option(teamId: 1, seasonId: 200, seasonName: '2025/26'),
        _option(
          teamId: 2,
          seasonId: 201,
          seasonName: '2025/26',
          teamName: 'Beta FC',
        ),
      ],
      comparisonLoader: (query) async {
        queries.add(query);
        return _comparisonFor(query, comparisonShortCode: 'BETA');
      },
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Beta FC'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analysis-form-option-2-201')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('analysis-filter-update')));
    await tester.pumpAndSettle();

    expect(queries.last.seasonId, 200);
    expect(queries.last.compareTeamId, 2);
    expect(queries.last.compareSeasonId, 201);
  });

  testWidgets('shows an option error and retries the repository request',
      (tester) async {
    var optionAttempts = 0;
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async {
        optionAttempts += 1;
        if (optionAttempts == 1) throw StateError('temporary failure');
        return _optionsForTeam(1);
      },
      comparisonLoader: (query) async =>
          _comparisonFor(query, comparisonShortCode: 'RECOVERED'),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('analysis-current-form-error')),
      findsOneWidget,
    );

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(optionAttempts, 2);
    expect(
      find.byKey(const ValueKey('analysis-current-form-chart-card')),
      findsOneWidget,
    );
    expect(find.text('24/25 RECOVERED'), findsNothing);
  });

  testWidgets('ignores a stale comparison after the selected team changes',
      (tester) async {
    final firstResult = Completer<CurrentFormComparison?>();
    final secondResult = Completer<CurrentFormComparison?>();
    final repository = _TestCurrentFormRepository(
      optionsLoader: (query) async => _optionsForTeam(query.teamId,
          currentSeasonName: query.seasonName ?? '2025/26'),
      comparisonLoader: (query) =>
          query.teamId == 1 ? firstResult.future : secondResult.future,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(buildSubject(teamId: 3, repository: repository));
    await tester.pump();
    await tester.pump();

    firstResult.complete(
      _comparisonFor(
        const CurrentFormComparisonQuery(
          teamId: 1,
          compareTeamId: 1,
          compareSeasonId: 100,
        ),
        comparisonShortCode: 'STALE',
      ),
    );
    await tester.pump();

    expect(find.textContaining('STALE'), findsNothing);
    expect(
      find.byKey(const ValueKey('analysis-current-form-loading')),
      findsOneWidget,
    );

    secondResult.complete(
      _comparisonFor(
        const CurrentFormComparisonQuery(
          teamId: 3,
          compareTeamId: 3,
          compareSeasonId: 100,
        ),
        comparisonShortCode: 'FRESH',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('STALE'), findsNothing);
    expect(find.textContaining('FRESH'), findsNothing);
    expect(
      find.byKey(const ValueKey('analysis-current-form-chart-card')),
      findsOneWidget,
    );
  });

  testWidgets('does not load or invent a fallback when no team is available',
      (tester) async {
    var optionLoads = 0;
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async {
        optionLoads += 1;
        return const [];
      },
      comparisonLoader: (_) async => null,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: null, repository: repository));
    await tester.pumpAndSettle();

    expect(optionLoads, 0);
    expect(
      find.byKey(const ValueKey('analysis-current-form-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('analysis-form-filter')), findsNothing);
  });

  testWidgets('does not use another team as the baseline', (tester) async {
    var comparisonLoads = 0;
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => [
        _option(
          teamId: 2,
          seasonId: 200,
          seasonName: '2025/26',
          teamName: 'Beta FC',
          shortCode: 'BET',
        ),
      ],
      comparisonLoader: (_) async {
        comparisonLoads += 1;
        return null;
      },
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();

    expect(comparisonLoads, 0);
    expect(
      find.byKey(const ValueKey('analysis-current-form-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('analysis-form-filter')), findsNothing);
  });

  testWidgets('fits a taller phone without layout exceptions', (tester) async {
    useScreen(tester, const Size(393, 852));
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => _optionsForTeam(1),
      comparisonLoader: (query) async =>
          _comparisonFor(query, comparisonShortCode: 'TALL'),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('24/25 TALL'), findsNothing);
    expect(
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses one grid cell for the Korean points axis label',
      (tester) async {
    useScreen(tester, const Size(393, 852));
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => _optionsForTeam(1),
      comparisonLoader: (query) async =>
          _comparisonFor(query, comparisonShortCode: 'PREV'),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildSubject(
        teamId: 1,
        repository: repository,
        locale: const Locale('ko'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('analysis-current-form-legend')),
        matching: find.text('현재 팀'),
      ),
      findsOneWidget,
    );
    expect(find.text('승점'), findsOneWidget);
    final pointsLabel = tester.widget<Text>(find.text('승점'));
    expect(pointsLabel.style, Body2_b.style);
    expect(pointsLabel.style?.fontSize, 14);
    expect(pointsLabel.style?.fontWeight, FontWeight.w700);
    expect(pointsLabel.style?.height, 1.2);
    final grid = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('analysis-current-form-grid')),
    );
    final dynamic painter = grid.painter;
    expect(painter.divisionCount, 3);
    expect(painter.insetLineCount, 2);
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect((lineChart.data.minY, lineChart.data.maxY), (0, 9));
    expect(lineChart.data.lineBarsData.first.spots.first.y, 3);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [darktheme, whitetheme]) {
    final isDark = theme.brightness == Brightness.dark;
    testWidgets(
      'shows separate ${isDark ? 'dark' : 'light'} value boxes for a selected round',
      (tester) async {
        useScreen(tester, const Size(393, 852));
        final repository = _TestCurrentFormRepository(
          optionsLoader: (_) async => _optionsForTeam(1),
          comparisonLoader: (query) async =>
              _comparisonFor(query, comparisonShortCode: 'PREV'),
        );
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          buildSubject(teamId: 1, repository: repository, theme: theme),
        );
        await tester.pumpAndSettle();

        await _chooseCurrentForm(tester, seasonId: 100, teamId: 1);

        final chart = find.byKey(
          const ValueKey('analysis-current-form-chart'),
        );
        final viewport = find.byKey(
          const ValueKey('analysis-current-form-viewport'),
        );
        final horizontalScroll = tester.widget<SingleChildScrollView>(
          find.descendant(
            of: viewport,
            matching: find.byType(SingleChildScrollView),
          ),
        );
        horizontalScroll.controller!.jumpTo(0);
        await tester.pump();
        final chartRect = tester.getRect(chart);
        final selectedPointX = chartRect.left + chartRect.width / 6;
        await tester.tapAt(Offset(selectedPointX, chartRect.center.dy));
        await tester.pump();

        final expectedBoxColor = isDark ? AppPalette.black : AppPalette.white;
        for (final key in const [
          ValueKey('analysis-current-form-current-tooltip'),
          ValueKey('analysis-current-form-comparison-tooltip'),
        ]) {
          final box = tester.widget<Container>(find.byKey(key));
          expect((box.decoration! as BoxDecoration).color, expectedBoxColor);
        }
        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        expect(lineChart.data.minX, 1);
        expect(lineChart.data.maxX, 7);
        expect(lineChart.data.minY, 0);
        expect(lineChart.data.maxY, 9);
        final comparisonTooltipRect = tester.getRect(
          find.byKey(
            const ValueKey('analysis-current-form-comparison-tooltip'),
          ),
        );
        final currentTooltipRect = tester.getRect(
          find.byKey(
            const ValueKey('analysis-current-form-current-tooltip'),
          ),
        );
        bool isHorizontallyAdjacent(Rect rect) =>
            (rect.left - (selectedPointX + 8)).abs() < 0.01 ||
            (rect.right - (selectedPointX - 8)).abs() < 0.01;
        expect(isHorizontallyAdjacent(comparisonTooltipRect), isTrue);
        expect(isHorizontallyAdjacent(currentTooltipRect), isTrue);
        expect(comparisonTooltipRect.center.dy,
            lessThan(currentTooltipRect.center.dy));
        expect(
          currentTooltipRect.center.dy - comparisonTooltipRect.center.dy,
          closeTo(40, 0.01),
        );
        expect(find.text('Round 2'), findsNWidgets(2));
        expect(find.text('4 Pts'), findsNWidgets(2));
        for (final label in ['Round 2', '4 Pts']) {
          for (final element in find.text(label).evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason:
                  '$label size=${paragraph.size} intrinsic=${paragraph.getMaxIntrinsicWidth(double.infinity)}',
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('opens all catalog options at compact width without overflow',
      (tester) async {
    useScreen(tester, const Size(320, 568));
    final repository = MockCurrentFormRepository();

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpAndSettle();

    final filterFinder = find.byKey(const ValueKey('analysis-form-filter'));
    final closedFilterWidth = tester.getSize(filterFinder).width;
    final options = await repository.loadOptions(83);
    final baseline = options.firstWhere((option) => option.teamId == 83);
    final visibleOptions = options
        .where(
          (option) =>
              option.teamId != baseline.teamId ||
              option.seasonId != baseline.seasonId,
        )
        .toList();
    expect(closedFilterWidth, 165);

    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();

    final firstOption = visibleOptions.first;
    await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
    await tester.pumpAndSettle();
    await tester.tap(find
        .byKey(ValueKey('analysis-filter-season-${firstOption.seasonName}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey(
        'analysis-form-option-${firstOption.teamId}-${firstOption.seasonId}')));
    expect(
      tester
          .getSize(
            find.byKey(
              ValueKey(
                'analysis-form-option-${firstOption.teamId}-${firstOption.seasonId}',
              ),
            ),
          )
          .width,
      greaterThanOrEqualTo(closedFilterWidth),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('opens immediately and ignores stale season responses at $size',
        (tester) async {
      useScreen(tester, size);
      final pending = Completer<List<CurrentFormOption>>();
      final queries = <CurrentFormOptionsQuery>[];
      final repository = _TestCurrentFormRepository(
        optionsLoader: (query) async {
          queries.add(query);
          if (query.seasonName == '2025/26') return pending.future;
          return _optionsForTeam(1);
        },
        comparisonLoader: (query) async =>
            _comparisonFor(query, comparisonShortCode: 'PREV'),
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('analysis-comparison-filter-sheet')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('analysis-filter-loading')),
          findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.byKey(const ValueKey('analysis-filter-update')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
      await tester.pump();
      final previous =
          find.byKey(const ValueKey('analysis-filter-season-2024/25'));
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(queries.map((query) => query.seasonName),
          [null, '2025/26', '2024/25']);
      pending.complete(_optionsForTeam(1));
      await tester.pumpAndSettle();
      final historical =
          find.byKey(const ValueKey('analysis-form-option-1-100'));
      await tester.ensureVisible(historical);
      expect(historical, findsOneWidget);
      expect(find.byKey(const ValueKey('analysis-form-option-2-200')),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'loads only the current season initially and keeps catalog seasons selectable',
      (tester) async {
    useScreen(tester, const Size(430, 932));
    final source = MockCurrentFormRepository();
    final queries = <CurrentFormOptionsQuery>[];
    final repository = _TestCurrentFormRepository(
      optionsLoader: (query) {
        queries.add(query);
        return source.loadOptions(query.teamId,
            seasonName: query.seasonName, limit: query.limit);
      },
      comparisonLoader: (query) => source.loadComparison(query.teamId,
          seasonId: query.seasonId,
          compareTeamId: query.compareTeamId,
          compareSeasonId: query.compareSeasonId),
    );
    addTearDown(repository.dispose);
    final currentSeason = footballCatalog.seasons.value.singleWhere(
        (season) => season.seasonId == footballCatalog.resolve(83)!.seasonId);
    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpAndSettle();
    expect(queries.single.seasonName, currentSeason.name);
    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
    await tester.pumpAndSettle();
    final previous =
        find.byKey(const ValueKey('analysis-filter-season-2024/2025'));
    await tester.ensureVisible(previous);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(queries.last.seasonName, '2024/2025');
    expect(queries.every((query) => query.seasonName != null), isTrue);
    final search = find.byKey(const ValueKey('analysis-filter-team-search'));
    await tester.scrollUntilVisible(search, -200,
        scrollable: find
            .descendant(
                of: find
                    .byKey(const ValueKey('analysis-comparison-filter-sheet')),
                matching: find.byType(Scrollable))
            .first);
    await tester.enterText(search, 'Barcelona');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analysis-form-option-83-23621')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries a failed season and disables empty results',
      (tester) async {
    var attempts = 0;
    final repository = _TestCurrentFormRepository(
      optionsLoader: (query) async {
        if (query.seasonName == null) return _optionsForTeam(1);
        if (++attempts == 1) throw StateError('Unavailable');
        return [];
      },
      comparisonLoader: (query) async =>
          _comparisonFor(query, comparisonShortCode: 'PREV'),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analysis-filter-error')), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.byKey(const ValueKey('analysis-filter-update')))
            .onPressed,
        isNull);
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('No teams found'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.byKey(const ValueKey('analysis-filter-update')))
            .onPressed,
        isNull);
  });

  testWidgets('ignores a pending option response after the sheet closes',
      (tester) async {
    final pending = Completer<List<CurrentFormOption>>();
    final repository = _TestCurrentFormRepository(
      optionsLoader: (query) async =>
          query.seasonName == null ? _optionsForTeam(1) : pending.future,
      comparisonLoader: (query) async =>
          _comparisonFor(query, comparisonShortCode: 'PREV'),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('analysis-filter-close')));
    await tester.pumpAndSettle();
    pending.complete(_optionsForTeam(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analysis-comparison-filter-sheet')),
        findsNothing);
    expect(find.byKey(const ValueKey('analysis-current-form-chart-card')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('season expansion pushes the team list and selection closes it',
      (tester) async {
    useScreen(tester, const Size(393, 852));
    final repository = _TestCurrentFormRepository(
      optionsLoader: (_) async => _optionsForTeam(1),
      comparisonLoader: (query) async =>
          _comparisonFor(query, comparisonShortCode: 'PREV'),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(buildSubject(teamId: 1, repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();

    final teamHeader = find.text('TEAM').last;
    final closedTop = tester.getTopLeft(teamHeader).dy;
    await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
    await tester.pump();
    expect(tester.getTopLeft(teamHeader).dy, greaterThan(closedTop));

    await tester
        .tap(find.byKey(const ValueKey('analysis-filter-season-2024/25')));
    await tester.pump();
    expect(find.byKey(const ValueKey('analysis-filter-season-2024/25')),
        findsNothing);
    expect(tester.getTopLeft(teamHeader).dy, closedTop);
  });
}

Future<void> _chooseCurrentForm(
  WidgetTester tester, {
  required int seasonId,
  required int teamId,
}) async {
  await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
  await tester.pumpAndSettle();
  final seasonName = seasonId == 200 ? '2025/26' : '2024/25';
  await tester.tap(find.byKey(ValueKey('analysis-filter-season-$seasonName')));
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('analysis-form-option-$teamId-$seasonId'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump();
  expect(
    tester
        .widget<ElevatedButton>(
          find.byKey(const ValueKey('analysis-filter-update')),
        )
        .onPressed,
    isNotNull,
  );
  await tester.tap(find.byKey(const ValueKey('analysis-filter-update')));
  await tester.pumpAndSettle();
}

List<CurrentFormOption> _optionsForTeam(int teamId,
    {String currentSeasonName = '2025/26'}) {
  return [
    _option(teamId: teamId, seasonId: 200, seasonName: currentSeasonName),
    _option(
      teamId: 2,
      seasonId: 200,
      seasonName: currentSeasonName,
      teamName: 'Beta FC',
      shortCode: 'BET',
    ),
    _option(teamId: teamId, seasonId: 100, seasonName: '2024/25'),
  ];
}

CurrentFormOption _option({
  required int teamId,
  required int seasonId,
  required String seasonName,
  String? teamName,
  String? shortCode,
}) {
  return CurrentFormOption(
    teamId: teamId,
    teamName: teamName ?? 'Team $teamId',
    teamShortCode: shortCode ?? 'T$teamId',
    leagueId: 8,
    seasonId: seasonId,
    seasonName: seasonName,
    roundsAvailable: 2,
    latestRound: 2,
  );
}

CurrentFormComparison _comparisonFor(
  CurrentFormComparisonQuery query, {
  required String comparisonShortCode,
}) {
  return CurrentFormComparison(
    current: _series(
      teamId: query.teamId,
      seasonId: query.seasonId ?? 200,
      seasonName: '2025/26',
      shortCode: 'CURRENT',
      isCurrent: true,
    ),
    comparison: _series(
      teamId: query.compareTeamId,
      seasonId: query.compareSeasonId,
      seasonName: query.compareSeasonId == 100 ? '2024/25' : '2025/26',
      shortCode: comparisonShortCode,
      isCurrent: false,
    ),
    maxRound: 2,
    maxPoints: 4,
  );
}

CurrentFormSeries _series({
  required int teamId,
  required int seasonId,
  required String seasonName,
  required String shortCode,
  required bool isCurrent,
}) {
  return CurrentFormSeries(
    teamId: teamId,
    teamName: 'Team $teamId',
    teamShortCode: shortCode,
    leagueId: 8,
    seasonId: seasonId,
    seasonName: seasonName,
    isCurrent: isCurrent,
    points: const [
      CurrentFormPoint(roundNo: 0, cumulativePoints: 0),
      CurrentFormPoint(roundNo: 1, cumulativePoints: 3),
      CurrentFormPoint(roundNo: 2, cumulativePoints: 4),
    ],
  );
}

class _TestCurrentFormRepository implements CurrentFormRepository {
  _TestCurrentFormRepository({
    required this.optionsLoader,
    required this.comparisonLoader,
  });

  final Future<List<CurrentFormOption>> Function(CurrentFormOptionsQuery query)
      optionsLoader;
  final Future<CurrentFormComparison?> Function(
    CurrentFormComparisonQuery query,
  ) comparisonLoader;
  final ValueNotifier<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      _cachedOptions = ValueNotifier(const {});
  final ValueNotifier<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      _cachedComparisons = ValueNotifier(const {});

  @override
  ValueListenable<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      get cachedOptions => _cachedOptions;

  @override
  ValueListenable<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      get cachedComparisons => _cachedComparisons;

  @override
  List<CurrentFormOption>? cachedOptionsFor(
    int teamId, {
    String search = '',
    String? seasonName,
    int limit = 200,
  }) {
    return _cachedOptions.value[CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      seasonName: seasonName,
      limit: limit,
    )];
  }

  @override
  CurrentFormComparison? cachedComparisonFor(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  }) {
    return _cachedComparisons.value[CurrentFormComparisonQuery(
      teamId: teamId,
      seasonId: seasonId,
      compareTeamId: compareTeamId,
      compareSeasonId: compareSeasonId,
    )];
  }

  @override
  Future<List<CurrentFormOption>> loadOptions(
    int teamId, {
    String search = '',
    String? seasonName,
    int limit = 200,
  }) async {
    final query = CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      seasonName: seasonName,
      limit: limit,
    );
    final cached = _cachedOptions.value[query];
    if (cached != null) return cached;

    final options = List<CurrentFormOption>.unmodifiable(
      (await optionsLoader(query)).where(
          (option) => seasonName == null || option.seasonName == seasonName),
    );
    _cachedOptions.value = Map.unmodifiable({
      ..._cachedOptions.value,
      query: options,
    });
    return options;
  }

  @override
  Future<List<CurrentFormOption>> loadAllOptions(int teamId,
          {String? seasonName}) =>
      loadOptions(teamId, seasonName: seasonName, limit: 1000);

  @override
  Future<CurrentFormComparison?> loadComparison(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  }) async {
    final query = CurrentFormComparisonQuery(
      teamId: teamId,
      seasonId: seasonId,
      compareTeamId: compareTeamId,
      compareSeasonId: compareSeasonId,
    );
    final cached = _cachedComparisons.value[query];
    if (cached != null) return cached;

    final comparison = await comparisonLoader(query);
    if (comparison != null) {
      _cachedComparisons.value = Map.unmodifiable({
        ..._cachedComparisons.value,
        query: comparison,
      });
    }
    return comparison;
  }

  void dispose() {
    _cachedOptions.dispose();
    _cachedComparisons.dispose();
  }
}
