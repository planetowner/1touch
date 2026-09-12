import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/MatchScreen_tabs/H2H.dart';

void main() {
  testWidgets('loads the selected H2H limit on a compact screen',
      (tester) async {
    await _setSize(tester, const Size(320, 568));
    final second = Completer<List<Fixture>>();
    final repository = _RecordingFixtureRepository(
      loader: (_, limit) => limit == 10
          ? second.future
          : Future.value([_pastFixture(homeScore: limit)]),
    );

    await tester.pumpWidget(
      _testApp(repository: repository),
    );
    await tester.pump();

    expect(repository.requests, [(fixtureId: 1001, limit: 5)]);
    expect(find.byKey(const ValueKey('match-h2h-wdl-card')), findsOneWidget);

    final dropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    dropdown.onChanged!(10);
    await tester.pump();
    expect(find.byKey(const ValueKey('match-h2h-loading')), findsOneWidget);
    second.complete([_pastFixture(homeScore: 10)]);
    await tester.pump();

    expect(repository.requests, [
      (fixtureId: 1001, limit: 5),
      (fixtureId: 1001, limit: 10),
    ]);
    expect(find.text('10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error and retries on a taller screen', (tester) async {
    await _setSize(tester, const Size(430, 932));
    var shouldFail = true;
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async {
        if (shouldFail) throw StateError('Unavailable');
        return [_pastFixture()];
      },
    );

    await tester.pumpWidget(
      _testApp(repository: repository),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('match-h2h-error')), findsOneWidget);
    expect(find.text('Unable to load head-to-head matches.'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump();

    expect(repository.requests, hasLength(2));
    expect(find.byKey(const ValueKey('match-h2h-wdl-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a stale result after the selected limit changes',
      (tester) async {
    await _setSize(tester, const Size(320, 568));
    final first = Completer<List<Fixture>>();
    final second = Completer<List<Fixture>>();
    final repository = _RecordingFixtureRepository(
      loader: (_, limit) => limit == 5 ? first.future : second.future,
    );

    await tester.pumpWidget(
      _testApp(repository: repository),
    );

    final dropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    dropdown.onChanged!(10);
    await tester.pump();

    second.complete([_pastFixture(homeScore: 10)]);
    await tester.pump();
    expect(find.text('10'), findsOneWidget);

    first.complete([_pastFixture(homeScore: 5)]);
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({required _RecordingFixtureRepository repository}) {
  return MaterialApp(
    home: Scaffold(
      body: H2HTab(
        fixture: _selectedFixture,
        fixtureRepository: repository,
      ),
    ),
  );
}

const _selectedFixture = Fixture(
  fixtureId: 1001,
  seasonId: 25583,
  competitionId: 8,
  homeTeamId: 8,
  awayTeamId: 19,
  competitionType: CompetitionType.league,
  roundName: '10',
  status: FixtureStatus.upcoming,
  startingAt: '2026-09-20 15:00:00',
);

Fixture _pastFixture({int homeScore = 2}) {
  return Fixture(
    fixtureId: 900,
    seasonId: 25583,
    competitionId: 8,
    homeTeamId: 8,
    awayTeamId: 19,
    competitionType: CompetitionType.league,
    roundName: '5',
    status: FixtureStatus.past,
    startingAt: '2026-01-10 15:00:00',
    homeScore: homeScore,
    awayScore: 1,
  );
}

typedef _HeadToHeadLoader = Future<List<Fixture>> Function(
  int fixtureId,
  int limit,
);

class _RecordingFixtureRepository extends MockFixtureRepository {
  _RecordingFixtureRepository({required this.loader})
      : super(fixtures: const [_selectedFixture]);

  final _HeadToHeadLoader loader;
  final List<({int fixtureId, int limit})> requests = [];

  @override
  Future<List<Fixture>> loadHeadToHead(
    int fixtureId, {
    int limit = 10,
  }) {
    requests.add((fixtureId: fixtureId, limit: limit));
    return loader(fixtureId, limit);
  }
}
