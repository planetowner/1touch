import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/data/standings/mock/mock_xg_standing_repository.dart';
import 'package:onetouch/features/knockout_bracket.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Standing.dart';

void main() {
  testWidgets('loads the selected competition and season from the repository',
      (tester) async {
    final repository = _ControlledStandingRepository(
      (_, __) async => [
        _standing(teamName: 'API United'),
        _standing(
          teamId: 19,
          position: 2,
          teamName: 'Second United',
        ),
      ],
    );

    await tester.pumpWidget(_app(repository));

    expect(find.byKey(const ValueKey('standing-loading')), findsOneWidget);
    expect(repository.requests, [(competitionId: 8, seasonId: 28083)]);

    final seasonDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-season-filter')),
    );
    expect(seasonDropdown.value, 28083);
    expect(
      seasonDropdown.items!.map((item) => item.value),
      [28083, 25583, 23614],
    );

    await tester.pump();

    expect(find.text('MCI'), findsOneWidget);
    expect(find.text('ARS'), findsOneWidget);
    expect(find.text('API United'), findsNothing);
    expect(find.text('Second United'), findsNothing);
    expect(find.byKey(const ValueKey('standing-loading')), findsNothing);

    final clubColumn = find.byKey(const ValueKey('standing-club-column'));
    expect(tester.getSize(clubColumn).width, 146);
    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();

    expect(find.text('API United'), findsOneWidget);
    expect(find.text('Second United'), findsOneWidget);
    expect(find.text('MCI'), findsNothing);
    expect(find.text('ARS'), findsNothing);
    expect(tester.getSize(clubColumn).width, 216);

    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('MCI'), findsOneWidget);
    expect(find.text('ARS'), findsOneWidget);
    expect(tester.getSize(clubColumn).width, 146);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows cached rows immediately while loading the same query',
      (tester) async {
    final pending = Completer<List<Standing>>();
    final repository = _ControlledStandingRepository(
      (_, __) => pending.future,
      cached: [_standing(teamName: 'Cached United')],
    );

    await tester.pumpWidget(_app(repository));

    expect(find.text('MCI'), findsOneWidget);
    expect(find.text('Cached United'), findsNothing);
    expect(find.byKey(const ValueKey('standing-loading')), findsNothing);

    pending.complete([_standing(teamName: 'Fresh United')]);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('Fresh United'), findsOneWidget);
    expect(find.text('Cached United'), findsNothing);
  });

  testWidgets('shows an error and retries the selected query', (tester) async {
    var shouldFail = true;
    final repository = _ControlledStandingRepository((_, __) async {
      if (shouldFail) throw StateError('network failed');
      return const [];
    });

    await tester.pumpWidget(_app(repository));
    await tester.pump();

    expect(find.text('Unable to load standings'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('standing-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('standing-empty')), findsOneWidget);
    expect(repository.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a late response after the season changes',
      (tester) async {
    final pending = <int, Completer<List<Standing>>>{};
    final repository = _ControlledStandingRepository(
      (_, seasonId) =>
          pending.putIfAbsent(seasonId!, Completer<List<Standing>>.new).future,
    );

    await tester.pumpWidget(_app(repository));

    final seasonDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-season-filter')),
    );
    seasonDropdown.onChanged!(23614);
    await tester.pump();

    pending[28083]!.complete([_standing(teamName: 'Stale United')]);
    await tester.pump();

    expect(find.text('Stale United'), findsNothing);
    expect(find.byKey(const ValueKey('standing-loading')), findsOneWidget);

    pending[23614]!.complete([
      _standing(
        seasonId: 23614,
        teamName: 'Current United',
      ),
    ]);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('Current United'), findsOneWidget);
    expect(repository.requests, [
      (competitionId: 8, seasonId: 28083),
      (competitionId: 8, seasonId: 23614),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads xG standings only after the xG table is selected',
      (tester) async {
    final xgRepository = _ControlledXgStandingRepository(
      (_, __) async => [_xgStanding(teamName: 'API Expected United')],
    );

    await tester.pumpWidget(_app(
      _successfulStandingRepository(),
      xgRepository: xgRepository,
    ));
    await tester.pump();

    expect(xgRepository.requests, isEmpty);

    await tester.tap(find.byKey(const ValueKey('standing-view-xg-table')));
    await tester.pump();

    expect(xgRepository.requests, [(competitionId: 8, seasonId: 28083)]);
    expect(find.text('MCI'), findsOneWidget);
    expect(find.text('API Expected United'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('API Expected United'), findsOneWidget);
    expect(find.byKey(const ValueKey('xg-standing-loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows cached xG rows while refreshing the selected query',
      (tester) async {
    final pending = Completer<List<XgStanding>>();
    final xgRepository = _ControlledXgStandingRepository(
      (_, __) => pending.future,
      cached: [_xgStanding(teamName: 'Cached Expected United')],
    );

    await tester.pumpWidget(_app(
      _successfulStandingRepository(),
      xgRepository: xgRepository,
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('standing-view-xg-table')));
    await tester.pump();

    expect(find.text('MCI'), findsOneWidget);
    expect(find.text('Cached Expected United'), findsNothing);
    expect(find.byKey(const ValueKey('xg-standing-loading')), findsNothing);

    pending.complete([_xgStanding(teamName: 'Fresh Expected United')]);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Expected United'), findsOneWidget);
    expect(find.text('Cached Expected United'), findsNothing);
  });

  testWidgets('shows an xG error and retries the selected query',
      (tester) async {
    var shouldFail = true;
    final xgRepository = _ControlledXgStandingRepository((_, __) async {
      if (shouldFail) throw StateError('network failed');
      return const [];
    });

    await tester.pumpWidget(_app(
      _successfulStandingRepository(),
      xgRepository: xgRepository,
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('standing-view-xg-table')));
    await tester.pump();

    expect(find.text('Unable to load xG standings'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('xg-standing-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('xg-standing-empty')), findsOneWidget);
    expect(xgRepository.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores an old xG response after the season changes',
      (tester) async {
    final pending = <int, Completer<List<XgStanding>>>{};
    final xgRepository = _ControlledXgStandingRepository(
      (_, seasonId) => pending
          .putIfAbsent(seasonId!, Completer<List<XgStanding>>.new)
          .future,
    );

    await tester.pumpWidget(_app(
      _successfulStandingRepository(),
      xgRepository: xgRepository,
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('standing-view-xg-table')));
    await tester.pump();

    final seasonDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-season-filter')),
    );
    seasonDropdown.onChanged!(23614);
    await tester.pump();

    pending[28083]!.complete([
      _xgStanding(teamName: 'Stale Expected United'),
    ]);
    await tester.pump();

    expect(find.text('Stale Expected United'), findsNothing);
    expect(find.byKey(const ValueKey('xg-standing-loading')), findsOneWidget);

    pending[23614]!.complete([
      _xgStanding(
        seasonId: 23614,
        teamName: 'Current Expected United',
      ),
    ]);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('Current Expected United'), findsOneWidget);
    expect(xgRepository.requests, [
      (competitionId: 8, seasonId: 28083),
      (competitionId: 8, seasonId: 23614),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'selects the requested overview competition and shows its tournament',
      (tester) async {
    final repository = _successfulStandingRepository();

    await tester.pumpWidget(
      _app(
        repository,
        requestedCompetitionId: 8,
        selectionRequestId: 0,
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      _app(
        repository,
        requestedCompetitionId: 2,
        selectionRequestId: 1,
      ),
    );
    await tester.pump();

    final leagueFilter = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-league-filter')),
    );
    final seasonFilter = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-season-filter')),
    );

    expect(leagueFilter.value, 2);
    expect(seasonFilter.value, 25580);
    expect(find.byType(KnockoutBracket), findsOneWidget);
    expect(
      find.byKey(const ValueKey('standing-view-standing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('standing-view-bracket')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('standing-view-standing')));
    await tester.pump();

    expect(find.byType(KnockoutBracket), findsNothing);
    expect(
      repository.requests,
      contains((competitionId: 2, seasonId: 25580)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not invent a default league for an unsupported team',
      (tester) async {
    final repository = _successfulStandingRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: StandingTab(
            team: const {'id': 999999},
            regularStandingRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requests, isEmpty);
    expect(
      find.byKey(const ValueKey('standing-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('standing-filter-row')), findsNothing);
  });
}

Widget _app(
  _ControlledStandingRepository repository, {
  _ControlledXgStandingRepository? xgRepository,
  int? requestedCompetitionId,
  int selectionRequestId = 0,
}) {
  return MaterialApp(
    theme: app_style.whitetheme,
    home: Scaffold(
      body: StandingTab(
        team: const {'id': 9},
        regularStandingRepository: repository,
        xgStandingRepository: xgRepository,
        requestedCompetitionId: requestedCompetitionId,
        selectionRequestId: selectionRequestId,
      ),
    ),
  );
}

_ControlledStandingRepository _successfulStandingRepository() {
  return _ControlledStandingRepository(
    (_, __) async => [_standing()],
  );
}

Standing _standing({
  int seasonId = 25583,
  int teamId = 9,
  int position = 1,
  String teamName = 'API United',
}) {
  return Standing(
    competitionId: 8,
    seasonId: seasonId,
    phase: StandingPhase.league,
    groupName: '',
    teamId: teamId,
    teamName: teamName,
    teamLogo: 'https://example.test/api-united.png',
    position: position,
    matchesPlayed: 3,
    won: 2,
    draw: 1,
    lost: 0,
    goalsFor: 8,
    goalsAgainst: 2,
    goalDiff: 6,
    points: 7,
    last5Form: const ['W', 'D'],
  );
}

XgStanding _xgStanding({
  int seasonId = 25583,
  String teamName = 'API Expected United',
}) {
  return XgStanding(
    competitionId: 8,
    seasonId: seasonId,
    teamId: 9,
    teamName: teamName,
    teamLogo: 'https://example.test/api-expected-united.png',
    position: 1,
    matchesPlayed: 3,
    xg: 8.125,
    xga: 2.5,
    xpts: 7.25,
    provider: 'understat',
    xptsMethod: 'historical_draw_rate',
  );
}

class _ControlledStandingRepository extends MockStandingRepository {
  _ControlledStandingRepository(
    this._loader, {
    List<Standing>? cached,
  })  : _cached = cached,
        super(standings: const []);

  final Future<List<Standing>> Function(int competitionId, int? seasonId)
      _loader;
  final List<Standing>? _cached;
  final requests = <({int competitionId, int? seasonId})>[];

  @override
  List<Standing>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    return _cached;
  }

  @override
  Future<List<Standing>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    requests.add((competitionId: competitionId, seasonId: seasonId));
    return _loader(competitionId, seasonId);
  }
}

class _ControlledXgStandingRepository extends MockXgStandingRepository {
  _ControlledXgStandingRepository(
    this._loader, {
    List<XgStanding>? cached,
  })  : _cached = cached,
        super(standings: const []);

  final Future<List<XgStanding>> Function(int competitionId, int? seasonId)
      _loader;
  final List<XgStanding>? _cached;
  final requests = <({int competitionId, int? seasonId})>[];

  @override
  List<XgStanding>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    return _cached;
  }

  @override
  Future<List<XgStanding>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    requests.add((competitionId: competitionId, seasonId: seasonId));
    return _loader(competitionId, seasonId);
  }
}
