import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/features/MatchInfoFeatures.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/screens/MatchScreen.dart';
import 'package:onetouch/screens/MatchScreen_tabs/matchinfo.dart';

void main() {
  testWidgets('loads a fixture detail asynchronously on a compact screen',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'upcoming',
          repository: repository,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('match-loading-indicator')),
      findsOneWidget,
    );
    expect(repository.calls, hasLength(1));

    repository.calls.single.complete(_detail());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries when fixture detail loading fails on a tall screen',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'upcoming',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Unable to load match.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('match-retry-button')));
    await tester.pump();
    expect(repository.calls, hasLength(2));

    repository.calls.last.complete(_detail());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an invalid fixture ID without calling the repository',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: 'not-a-number',
          matchStatus: 'upcoming',
          repository: repository,
        ),
      ),
    );

    expect(find.text('Match not found'), findsOneWidget);
    expect(repository.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a route fixture visible when detail is unavailable',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'upcoming',
          initialFixture: _fixture,
          repository: repository,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('match-loading-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );

    repository.calls.single.completeError(StateError('no mock detail'));
    await tester.pump();

    expect(find.text('Unable to load match.'), findsNothing);
    expect(
      find.byKey(const ValueKey('match-betting-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes the loaded fixture detail to Match Info', (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();
    final detail = _detail(
      coaches: [
        FixtureCoach(
          teamId: _fixture.awayTeamId,
          coachId: 902,
          name: 'Away Coach',
        ),
        FixtureCoach(
          teamId: _fixture.homeTeamId,
          coachId: 901,
          name: 'Home Coach',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'past',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.complete(detail);
    await tester.pump();

    final matchInfo = tester.widget<MatchInfoTab>(find.byType(MatchInfoTab));
    final coaches = tester.widget<SubstitutesAndCoach>(
      find.byType(SubstitutesAndCoach),
    );
    expect(matchInfo.detail, same(detail));
    expect(matchInfo.fixture, same(detail.fixture));
    expect(coaches.coachA, 'Home Coach');
    expect(coaches.coachB, 'Away Coach');
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a neutral label when fixture coach data is missing',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledFixtureRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: MatchScreen(
          matchId: '${_fixture.fixtureId}',
          matchStatus: 'past',
          repository: repository,
        ),
      ),
    );

    repository.calls.single.complete(_detail());
    await tester.pump();

    final coaches = tester.widget<SubstitutesAndCoach>(
      find.byType(SubstitutesAndCoach),
    );
    expect(coaches.coachA, '—');
    expect(coaches.coachB, '—');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final Fixture _fixture = mockFixtures.firstWhere(
  (fixture) => fixture.fixtureId == 20100001,
);

FixtureDetail _detail({List<FixtureCoach> coaches = const []}) {
  return FixtureDetail(
    fixture: _fixture,
    venueName: null,
    expectedGoals: null,
    playerExpectedGoals: const [],
    shots: const [],
    events: const [],
    statistics: const [],
    lineups: const [],
    formations: const [],
    coaches: coaches,
    pressure: const [],
  );
}

class _ControlledFixtureRepository extends MockFixtureRepository {
  _ControlledFixtureRepository() : super(fixtures: const []);

  final List<Completer<FixtureDetail>> calls = [];

  @override
  Future<FixtureDetail> loadDetail(int fixtureId) {
    final completer = Completer<FixtureDetail>();
    calls.add(completer);
    return completer.future;
  }
}
