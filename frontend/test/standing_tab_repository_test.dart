import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/data/standings/mock/mock_xg_standing_repository.dart';
import 'package:onetouch/features/api_knockout_bracket.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Standing.dart';

void main() {
  setUpAppCatalog();
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
    final standingCard = tester.widget<Container>(
      find.byKey(const ValueKey('standing-table-card')),
    );
    expect(
      (standingCard.decoration as BoxDecoration).boxShadow,
      app_style.lightModeCardShadows,
    );

    final clubColumn = find.byKey(const ValueKey('standing-club-column'));
    expect(tester.getSize(clubColumn).width, 130);
    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();

    expect(find.text('API United'), findsOneWidget);
    expect(find.text('Second United'), findsOneWidget);
    expect(find.text('MCI'), findsNothing);
    expect(find.text('ARS'), findsNothing);
    expect(tester.getSize(clubColumn).width, 226);

    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('MCI'), findsOneWidget);
    expect(find.text('ARS'), findsOneWidget);
    expect(tester.getSize(clubColumn).width, 130);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the approved standing table geometry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_ControlledStandingRepository(
      (_, __) async => [
        _standing(teamName: 'API United'),
        _standing(teamId: 19, position: 2, teamName: 'Second United'),
      ],
    )));
    await tester.pump();

    final card = find.byKey(const ValueKey('standing-table-card'));
    final clubColumn = find.byKey(const ValueKey('standing-club-column'));
    final cardWidget = tester.widget<Container>(card);
    final decoration = cardWidget.decoration! as BoxDecoration;
    final clubHeader = tester.widget<Container>(
      find.byKey(const ValueKey('standing-club-header')),
    );
    final statsHeader = tester.widget<Container>(
      find.byKey(const ValueKey('standing-stats-header')),
    );

    expect(tester.getSize(card).width, 345);
    expect(tester.getSize(clubColumn).width, 130);
    expect(decoration.borderRadius, BorderRadius.circular(24));
    expect(clubHeader.padding, const EdgeInsets.fromLTRB(16, 24, 16, 16));
    expect(statsHeader.padding, const EdgeInsets.fromLTRB(16, 24, 16, 16));
    expect(
      tester.getTopRight(clubColumn).dx -
          tester
              .getTopRight(find.byKey(const ValueKey('standing-club-name-9')))
              .dx,
      16,
    );
    expect(
      tester.getTopLeft(find.text('Club')).dx,
      tester.getTopLeft(find.text('MCI')).dx,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('standing-logo-9'))).dx -
          tester.getTopRight(find.byKey(const ValueKey('standing-rank-9'))).dx,
      12,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('standing-club-name-9'))).dx -
          tester.getTopRight(find.byKey(const ValueKey('standing-logo-9'))).dx,
      12,
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('standing-club-header')))
          .dy,
      tester
          .getBottomLeft(find.byKey(const ValueKey('standing-stats-header')))
          .dy,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('standing-header-divider'))),
      const Size(345, 1),
    );
    expect(
      tester.getCenter(find.text('W')).dx -
          tester.getCenter(find.text('MP')).dx,
      32,
    );
    final cardRight = tester.getTopRight(card).dx;
    final gdRect = tester.getRect(find.text('GD'));
    expect(gdRect.left, lessThan(cardRight));
    expect(gdRect.right, greaterThan(cardRight));
    expect(
      tester.getCenter(find.text('ARS')).dy -
          tester.getCenter(find.text('MCI')).dy,
      32,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('standing-last-five-9-0')),
          )
          .icon,
      Icons.check_circle,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('standing-last-five-9-1')),
          )
          .icon,
      Icons.remove_circle,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('standing-last-five-9-2')),
          )
          .icon,
      Icons.cancel,
    );
    final firstMarker =
        find.byKey(const ValueKey('standing-qualification-marker-9'));
    final secondMarker =
        find.byKey(const ValueKey('standing-qualification-marker-19'));
    expect(tester.getSize(firstMarker), const Size(2, 24));
    expect(tester.getSize(secondMarker), const Size(2, 24));
    expect(
      tester.getTopLeft(secondMarker).dy - tester.getBottomLeft(firstMarker).dy,
      8,
    );
    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(tester.getSize(clubColumn).width, 209);
    expect(
      tester.getRect(find.text('L')).right,
      lessThanOrEqualTo(cardRight),
    );
    expect(find.byKey(const ValueKey('standing-right-fade')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Club')).dx,
      tester.getTopLeft(find.text('API United')).dx,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('standing-club-name-9'))).dx -
          tester.getTopRight(find.byKey(const ValueKey('standing-logo-9'))).dx,
      12,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers Korean standing headers over their data columns',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(
      _successfulStandingRepository(),
      locale: const Locale('ko'),
    ));
    await tester.pump();

    for (final column in ['gf', 'ga', 'gd', 'pts']) {
      final header = find.byKey(ValueKey('standing-header-$column'));
      final data = find.byKey(ValueKey('standing-stat-9-$column'));

      expect(tester.getCenter(header).dx, tester.getCenter(data).dx);
      expect(tester.getSize(header).width, 24);
    }

    for (final label in ['득점', '실점', '득실차', '승점']) {
      final textRect = tester.getRect(find.text(label));
      final headerRect = tester.getRect(
        find.byKey(ValueKey('standing-header-${switch (label) {
          '득점' => 'gf',
          '실점' => 'ga',
          '득실차' => 'gd',
          _ => 'pts',
        }}')),
      );
      expect(textRect.center.dx, headerRect.center.dx);
      expect(textRect.width, lessThanOrEqualTo(headerRect.width));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps MP through L visible when club names expand on SE3',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_successfulStandingRepository()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('standing-table-card'));
    final clubColumn = find.byKey(const ValueKey('standing-club-column'));
    expect(tester.getSize(clubColumn).width, 191);
    expect(
      tester.getRect(find.text('L')).right,
      lessThanOrEqualTo(tester.getRect(card).right),
    );
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
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    final xgCard = tester.widget<Container>(
      find.byKey(const ValueKey('xg-standing-table-card')),
    );
    expect(
      (xgCard.decoration as BoxDecoration).boxShadow,
      app_style.lightModeCardShadows,
    );
    final xgHeader = find.byKey(const ValueKey('standing-stats-header'));
    expect(tester.getSize(xgHeader).width, 215);
    expect(
      tester.getTopRight(xgHeader).dx,
      tester
          .getTopRight(find.byKey(const ValueKey('xg-standing-table-card')))
          .dx,
    );
    for (final title in ['MP', 'xG', 'xGA', 'xPts']) {
      final headerText = tester.widget<Text>(find.text(title));
      expect(headerText.maxLines, 1);
      expect(headerText.softWrap, isFalse);
    }
    expect(
      tester.getCenter(find.text('xG')).dx -
          tester.getCenter(find.text('MP')).dx,
      44,
    );
    expect(
      tester.getCenter(find.text('xGA')).dx -
          tester.getCenter(find.text('xG')).dx,
      44,
    );
    expect(
      tester.getCenter(find.text('xPts')).dx -
          tester.getCenter(find.text('xGA')).dx,
      44,
    );
    await tester.tap(find.byKey(const ValueKey('standing-club-name-9')));
    await tester.pumpAndSettle();
    expect(find.text('API Expected United'), findsOneWidget);
    expect(find.byKey(const ValueKey('xg-standing-loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final screenWidth in [320.0, 430.0]) {
    testWidgets('xG table fills the stats viewport at ${screenWidth.toInt()}px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(screenWidth, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(
        _successfulStandingRepository(),
        xgRepository: _ControlledXgStandingRepository(
          (_, __) async => [_xgStanding()],
        ),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('standing-view-xg-table')));
      await tester.pump();

      final viewportWidth = screenWidth - 48 - 130;
      final expectedContentWidth = viewportWidth < 215 ? 215.0 : viewportWidth;
      expect(
        tester
            .getSize(find.byKey(const ValueKey('standing-stats-header')))
            .width,
        expectedContentWidth,
      );
      expect(tester.takeException(), isNull);
    });
  }

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
    await tester.tap(find.byKey(const ValueKey('standing-view-bracket')));
    await tester.pump();
    expect(find.byType(ApiKnockoutBracket), findsOneWidget);
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

    expect(find.byType(ApiKnockoutBracket), findsNothing);
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
  Locale? locale,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ko')],
    localizationsDelegates: appLocalizationDelegates,
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
    last5Form: const ['W', 'D', 'L'],
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
