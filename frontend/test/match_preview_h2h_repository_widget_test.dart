import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/MatchScreen_tabs/matchpreview.dart';

void main() {
  testWidgets('loads the latest H2H fixture on a compact screen',
      (tester) async {
    await _setSize(tester, const Size(320, 568));
    final result = Completer<List<Fixture>>();
    final repository = _RecordingFixtureRepository(
      loader: (_, __) => result.future,
    );

    await tester.pumpWidget(
      _testApp(fixture: _firstSelectedFixture, repository: repository),
    );

    expect(repository.requests, [(fixtureId: 1001, limit: 1)]);
    expect(
      find.byKey(const ValueKey('match-preview-h2h-loading')),
      findsOneWidget,
    );

    result.complete([_pastFixture(homeScore: 3)]);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-preview-h2h-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state when there are no previous meetings',
      (tester) async {
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async => const [],
    );

    await tester.pumpWidget(
      _testApp(fixture: _firstSelectedFixture, repository: repository),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-preview-h2h-empty')),
      findsOneWidget,
    );
    expect(find.text('No previous meetings found.'), findsOneWidget);
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
      _testApp(fixture: _firstSelectedFixture, repository: repository),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-preview-h2h-error')),
      findsOneWidget,
    );
    expect(find.text('Unable to load the latest meeting.'), findsOneWidget);

    shouldFail = false;
    await tester.ensureVisible(find.text('RETRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump();

    expect(repository.requests, hasLength(2));
    expect(
      find.byKey(const ValueKey('match-preview-h2h-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores an older result after the selected fixture changes',
      (tester) async {
    final first = Completer<List<Fixture>>();
    final second = Completer<List<Fixture>>();
    final repository = _RecordingFixtureRepository(
      loader: (fixtureId, _) =>
          fixtureId == 1001 ? first.future : second.future,
    );

    await tester.pumpWidget(
      _testApp(fixture: _firstSelectedFixture, repository: repository),
    );
    await tester.pumpWidget(
      _testApp(fixture: _secondSelectedFixture, repository: repository),
    );

    second.complete([_pastFixture(homeScore: 4)]);
    await tester.pump();
    final card = find.byKey(const ValueKey('match-preview-h2h-card'));
    expect(find.descendant(of: card, matching: find.text('4')), findsOneWidget);

    first.complete([_pastFixture(homeScore: 2)]);
    await tester.pump();

    expect(find.descendant(of: card, matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('2')), findsNothing);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({
  required Fixture fixture,
  required _RecordingFixtureRepository repository,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MatchPreviewTab(
        fixture: fixture,
        fixtureRepository: repository,
      ),
    ),
  );
}

const _firstSelectedFixture = Fixture(
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

const _secondSelectedFixture = Fixture(
  fixtureId: 1002,
  seasonId: 25583,
  competitionId: 8,
  homeTeamId: 8,
  awayTeamId: 19,
  competitionType: CompetitionType.league,
  roundName: '11',
  status: FixtureStatus.upcoming,
  startingAt: '2026-09-27 15:00:00',
);

Fixture _pastFixture({int homeScore = 1}) {
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
    awayScore: 0,
  );
}

typedef _HeadToHeadLoader = Future<List<Fixture>> Function(
  int fixtureId,
  int limit,
);

class _RecordingFixtureRepository extends MockFixtureRepository {
  _RecordingFixtureRepository({required this.loader})
      : super(fixtures: const [
          _firstSelectedFixture,
          _secondSelectedFixture,
        ]);

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
