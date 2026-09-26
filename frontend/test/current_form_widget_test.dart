import 'support/app_catalog.dart';
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/current_form/mock/mock_current_form_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/current_form.dart';
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
            team: teamId == null ? null : <String, dynamic>{'id': teamId},
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
    final filter = find.byKey(const ValueKey('analysis-form-filter'));
    expect(filter, findsOneWidget);
    expect(tester.getSize(filter).width, 165);
    expect(
      find.descendant(of: filter, matching: find.text('SEASON')),
      findsOneWidget,
    );
    final legend = find.byKey(const ValueKey('analysis-current-form-legend'));
    expect(find.descendant(of: legend, matching: find.text('CURRENT')),
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

    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('analysis-form-option-2-200')),
    );
    await tester.pumpAndSettle();

    expect(queries, hasLength(2));
    expect(queries.last.seasonId, 200);
    expect(queries.last.compareTeamId, 2);
    expect(queries.last.compareSeasonId, 200);
    expect(find.text('25/26 BETA'), findsOneWidget);
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
      optionsLoader: (query) async => _optionsForTeam(query.teamId),
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
    expect(painter.divisionCount, 11);
    expect(painter.insetLineCount, 2);
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

        await tester.tap(
          find.byKey(const ValueKey('analysis-form-filter')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('analysis-form-option-1-100')),
        );
        await tester.pumpAndSettle();

        final chart = find.byKey(
          const ValueKey('analysis-current-form-chart'),
        );
        final chartRect = tester.getRect(chart);
        final selectedPointX = chartRect.left + chartRect.width / 36;
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
        expect(lineChart.data.maxX, 36);
        expect(lineChart.data.maxY, 108);
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
        expect(find.text('Round 1'), findsNWidgets(2));
        expect(find.text('1 Pts'), findsNWidgets(2));
        for (final label in ['Round 1', '1 Pts']) {
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
    final popup = tester.widget<AppDropdown<CurrentFormOption>>(
      filterFinder,
    );
    final options = await repository.loadOptions(83);
    final baseline = options.firstWhere((option) => option.teamId == 83);
    final visibleOptions = options
        .where(
          (option) =>
              option.teamId != baseline.teamId ||
              option.seasonId != baseline.seasonId,
        )
        .toList();
    expect(popup.options, hasLength(visibleOptions.length));
    expect(
      popup.options.map((item) => (item.value.teamId, item.value.seasonId)),
      visibleOptions.map((option) => (option.teamId, option.seasonId)),
    );
    expect(popup.width, 165);
    expect(popup.matchMenuWidth, isFalse);
    expect(popup.maxMenuHeight, 272);

    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();

    expect(find.textContaining('BAR'), findsWidgets);
    final firstOption = visibleOptions.first;
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
}

List<CurrentFormOption> _optionsForTeam(int teamId) {
  return [
    _option(teamId: teamId, seasonId: 200, seasonName: '2025/26'),
    _option(
      teamId: 2,
      seasonId: 200,
      seasonName: '2025/26',
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
      CurrentFormPoint(roundNo: 1, cumulativePoints: 1),
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
    int limit = 200,
  }) {
    return _cachedOptions.value[CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
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
    int limit = 200,
  }) async {
    final query = CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      limit: limit,
    );
    final cached = _cachedOptions.value[query];
    if (cached != null) return cached;

    final options = List<CurrentFormOption>.unmodifiable(
      await optionsLoader(query),
    );
    _cachedOptions.value = Map.unmodifiable({
      ..._cachedOptions.value,
      query: options,
    });
    return options;
  }

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
