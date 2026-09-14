import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Standing.dart';

void main() {
  testWidgets('loads the selected competition and season from the repository',
      (tester) async {
    final repository = _ControlledStandingRepository(
      (_, __) async => [_standing(teamName: 'API United')],
    );

    await tester.pumpWidget(_app(repository));

    expect(find.byKey(const ValueKey('standing-loading')), findsOneWidget);
    expect(repository.requests, [(competitionId: 8, seasonId: 25583)]);

    await tester.pump();

    expect(find.text('API United'), findsOneWidget);
    expect(find.byKey(const ValueKey('standing-loading')), findsNothing);
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

    expect(find.text('Cached United'), findsOneWidget);
    expect(find.byKey(const ValueKey('standing-loading')), findsNothing);

    pending.complete([_standing(teamName: 'Fresh United')]);
    await tester.pump();

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

    pending[25583]!.complete([_standing(teamName: 'Stale United')]);
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

    expect(find.text('Current United'), findsOneWidget);
    expect(repository.requests, [
      (competitionId: 8, seasonId: 25583),
      (competitionId: 8, seasonId: 23614),
    ]);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(_ControlledStandingRepository repository) {
  return MaterialApp(
    theme: app_style.whitetheme,
    home: Scaffold(
      body: StandingTab(
        team: const {'id': 9},
        regularStandingRepository: repository,
      ),
    ),
  );
}

Standing _standing({
  int seasonId = 25583,
  String teamName = 'API United',
}) {
  return Standing(
    competitionId: 8,
    seasonId: seasonId,
    phase: StandingPhase.league,
    groupName: '',
    teamId: 9,
    teamName: teamName,
    teamLogo: 'https://example.test/api-united.png',
    position: 1,
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
