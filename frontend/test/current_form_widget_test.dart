import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/current_form/mock/mock_current_form_repository.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Analysis.dart';

void main() {
  Widget buildSubject({
    required int? teamId,
    required CurrentFormRepository repository,
  }) {
    return MaterialApp(
      theme: whitetheme,
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

  testWidgets('loads the same team previous season by default at compact width',
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

    expect(queries, hasLength(1));
    expect(queries.single.compareTeamId, 1);
    expect(queries.single.compareSeasonId, 100);
    expect(find.text('2024/25 PREV'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-form-filter')), findsOneWidget);
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
    await tester.tap(find.text('BET').last);
    await tester.pumpAndSettle();

    expect(queries, hasLength(2));
    expect(queries.last.compareTeamId, 2);
    expect(queries.last.compareSeasonId, 200);
    expect(find.text('2025/26 BETA'), findsOneWidget);
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
    expect(find.text('2024/25 RECOVERED'), findsOneWidget);
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
    expect(find.text('2024/25 FRESH'), findsOneWidget);
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

    expect(find.text('2024/25 TALL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens all 192 catalog options at compact width without overflow',
      (tester) async {
    useScreen(tester, const Size(320, 568));
    final repository = MockCurrentFormRepository();

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<CurrentFormOption>>(
      find.byKey(const ValueKey('analysis-form-filter')),
    );
    expect(dropdown.items, hasLength(192));

    await tester.tap(find.byKey(const ValueKey('analysis-form-filter')));
    await tester.pumpAndSettle();

    expect(find.text('BAR'), findsWidgets);
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
