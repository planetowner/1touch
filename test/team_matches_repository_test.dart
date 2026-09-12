import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Matches.dart';

void main() {
  testWidgets('loads each match status asynchronously', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = {
      for (final status in [
        FixtureStatus.past,
        FixtureStatus.live,
        FixtureStatus.upcoming,
      ])
        status: Completer<List<Fixture>>(),
    };
    final requestedStatuses = <FixtureStatus?>[];
    final repository = _ControlledFixtureRepository(
      (teamId, status, limit) {
        expect(teamId, 9);
        expect(limit, 200);
        requestedStatuses.add(status);
        return pending[status]!.future;
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));

    expect(find.byKey(const ValueKey('matches-loading')), findsOneWidget);
    expect(
      requestedStatuses,
      [FixtureStatus.past, FixtureStatus.live, FixtureStatus.upcoming],
    );

    pending[FixtureStatus.past]!.complete([_fixture(1, FixtureStatus.past)]);
    pending[FixtureStatus.live]!.complete([_fixture(2, FixtureStatus.live)]);
    pending[FixtureStatus.upcoming]!
        .complete([_fixture(3, FixtureStatus.upcoming)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-inline-live-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-inline-past-header')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error and retries the complete request set',
      (tester) async {
    var shouldFail = true;
    var requestCount = 0;
    final repository = _ControlledFixtureRepository(
      (_, __, ___) async {
        requestCount++;
        if (shouldFail) throw StateError('network failed');
        return const [];
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pump();

    expect(find.text('Unable to load matches'), findsOneWidget);
    expect(find.byKey(const ValueKey('matches-retry')), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('matches-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('matches-empty')), findsOneWidget);
    expect(requestCount, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores an old response after switching teams', (tester) async {
    final pending = <(int, FixtureStatus), Completer<List<Fixture>>>{};
    final repository = _ControlledFixtureRepository(
      (teamId, status, _) {
        final key = (teamId, status!);
        return pending.putIfAbsent(key, Completer.new).future;
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pumpWidget(_app(repository, teamId: 8));

    for (final status in [
      FixtureStatus.past,
      FixtureStatus.live,
      FixtureStatus.upcoming,
    ]) {
      pending[(9, status)]!.complete([_fixture(9, status)]);
    }
    await tester.pump();

    expect(find.byKey(const ValueKey('matches-loading')), findsOneWidget);

    for (final status in [
      FixtureStatus.past,
      FixtureStatus.live,
      FixtureStatus.upcoming,
    ]) {
      pending[(8, status)]!.complete(const []);
    }
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('matches-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(MockFixtureRepository repository, {required int teamId}) {
  return MaterialApp(
    home: Scaffold(
      body: MatchesTab(
        team: {'id': teamId},
        fixtureRepository: repository,
      ),
    ),
  );
}

Fixture _fixture(int fixtureId, FixtureStatus status) {
  return Fixture(
    fixtureId: fixtureId,
    competitionId: 8,
    seasonId: 25583,
    competitionType: CompetitionType.league,
    homeTeamId: 9,
    awayTeamId: 8,
    status: status,
    roundName: '1',
    startingAt: '2026-09-12 15:00:00',
  );
}

class _ControlledFixtureRepository extends MockFixtureRepository {
  _ControlledFixtureRepository(this._loader) : super(fixtures: const []);

  final Future<List<Fixture>> Function(
    int teamId,
    FixtureStatus? status,
    int limit,
  ) _loader;

  @override
  Future<List<Fixture>> loadForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) {
    return _loader(teamId, status, limit);
  }
}
