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
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledFixtureRepository();
    final detail = _detail(
      venueName: 'Test Stadium',
      expectedGoals: const FixtureExpectedGoals(
        homeXg: 0.518846,
        awayXg: 4.76916,
        homeXga: 4.76916,
        awayXga: 0.518846,
        provider: 'understat',
      ),
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
      statistics: [
        FixtureStatistic(
          teamId: _fixture.awayTeamId,
          statTypeId: 45,
          statCode: 'ball-possession',
          statName: 'Ball Possession',
          value: 36.4,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 45,
          statCode: 'ball-possession',
          statName: 'Ball Possession',
          value: 63.6,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 42,
          statCode: 'shots-total',
          statName: 'Shots Total',
          value: 10,
        ),
        FixtureStatistic(
          teamId: _fixture.awayTeamId,
          statTypeId: 42,
          statCode: 'shots-total',
          statName: 'Shots Total',
          value: 6,
        ),
        FixtureStatistic(
          teamId: _fixture.homeTeamId,
          statTypeId: 84,
          statCode: 'yellowcards',
          statName: 'Yellow Cards',
          value: 2,
        ),
      ],
      events: _matchEvents,
      lineups: _lineups,
      formations: [
        FixtureFormation(
          teamId: _fixture.homeTeamId,
          formation: '4-3-3',
        ),
        FixtureFormation(
          teamId: _fixture.awayTeamId,
          formation: '4-2-3-1',
        ),
      ],
      pressure: [
        FixturePressurePoint(
          teamId: _fixture.homeTeamId,
          minute: 10,
          pressure: 0.7,
        ),
        FixturePressurePoint(
          teamId: _fixture.awayTeamId,
          minute: 20,
          pressure: 0.4,
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
    final statistics = tester.widget<StatBarsSection>(
      find.byType(StatBarsSection),
    );
    final scoreHeader = tester.widget<MatchScoreHeader>(
      find.byType(MatchScoreHeader),
    );
    final events = tester.widget<MatchEventsSection>(
      find.byType(MatchEventsSection),
    );
    final momentum = tester.widget<MomentumChart>(
      find.byType(MomentumChart),
    );
    final lineup = tester.widget<LineupPitch>(find.byType(LineupPitch));
    final expectedGoals = statistics.bars.singleWhere(
      (bar) => bar.category == 'Expected Goals',
    );
    final possession = statistics.bars.singleWhere(
      (bar) => bar.category == 'Possession',
    );
    final yellowCards = statistics.bars.singleWhere(
      (bar) => bar.category == 'Yellow Cards',
    );
    expect(matchInfo.detail, same(detail));
    expect(matchInfo.fixture, same(detail.fixture));
    expect(coaches.coachA, 'Home Coach');
    expect(coaches.coachB, 'Away Coach');
    expect(scoreHeader.venueLabel, 'Test Stadium');
    expect(scoreHeader.statusLabel, 'Final');
    expect(
      events.events,
      contains(
        predicate<Map<String, dynamic>>(
          (event) =>
              event['player'] == 'Home Starter' &&
              event['minute'] == "45+2'" &&
              event['team'] == 'home' &&
              event['type'] == 'goal',
        ),
      ),
    );
    expect(
      events.events,
      contains(
        predicate<Map<String, dynamic>>(
          (event) =>
              event['player'] == 'Away Defender' &&
              event['minute'] == "70'" &&
              event['team'] == 'away' &&
              event['type'] == 'redCard',
        ),
      ),
    );
    expect(expectedGoals.homePercent, 0.518846);
    expect(expectedGoals.awayPercent, 4.76916);
    expect(expectedGoals.isPercent, isFalse);
    expect(expectedGoals.fractionDigits, 2);
    expect(possession.homePercent, 63.6);
    expect(possession.awayPercent, 36.4);
    expect(possession.isPercent, isTrue);
    expect(statistics.bars.map((bar) => bar.category), [
      'Possession',
      'Expected Goals',
      'Shots',
      'Yellow Cards',
    ]);
    expect(yellowCards.homePercent, 2);
    expect(yellowCards.awayPercent, 0);
    expect(momentum.values[10], 0.7);
    expect(momentum.values[20], -0.4);
    expect(lineup.homeFormation, '4-3-3');
    expect(lineup.awayFormation, '4-2-3-1');
    expect(lineup.homeRows.first.single.name, 'Home Starter');
    expect(
      lineup.homeRows.first.single.events.map((event) => event.type),
      containsAll([LineupEventType.goal, LineupEventType.subOut]),
    );
    expect(lineup.homeRows.last.single.name, 'Home Keeper');
    expect(lineup.awayRows.first.single.name, 'Away Keeper');
    expect(
      lineup.awayRows[1].single.events.map((event) => event.type),
      contains(LineupEventType.redCard),
    );
    expect(coaches.subsA.single.name, 'Home Substitute');
    expect(coaches.subsA.single.minute, 80);
    expect(coaches.subsA.single.subIn, isTrue);
    expect(coaches.subsB.single.name, 'Away Substitute');
    expect(coaches.subsB.single.minute, 75);
    expect(find.byKey(const ValueKey('match-player-of-the-match-card')),
        findsNothing);
    expect(find.text('0.52'), findsOneWidget);
    expect(find.text('4.77'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses neutral labels and omits incomplete detail statistics',
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

    repository.calls.single.complete(
      _detail(
        statistics: [
          FixtureStatistic(
            teamId: _fixture.homeTeamId,
            statTypeId: 45,
            statCode: 'ball-possession',
            statName: 'Ball Possession',
            value: 63.6,
          ),
        ],
      ),
    );
    await tester.pump();

    final coaches = tester.widget<SubstitutesAndCoach>(
      find.byType(SubstitutesAndCoach),
    );
    expect(coaches.coachA, '—');
    expect(coaches.coachB, '—');
    expect(find.byType(StatBarsSection), findsNothing);
    expect(find.byType(MatchEventsSection), findsNothing);
    expect(find.byType(MomentumChart), findsNothing);
    expect(find.byType(LineupPitch), findsNothing);
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

FixtureDetail _detail({
  String? venueName,
  FixtureExpectedGoals? expectedGoals,
  List<FixtureCoach> coaches = const [],
  List<FixtureStatistic> statistics = const [],
  List<FixtureEvent> events = const [],
  List<FixtureLineupEntry> lineups = const [],
  List<FixtureFormation> formations = const [],
  List<FixturePressurePoint> pressure = const [],
}) {
  return FixtureDetail(
    fixture: _fixture,
    venueName: venueName,
    expectedGoals: expectedGoals,
    playerExpectedGoals: const [],
    shots: const [],
    events: events,
    statistics: statistics,
    lineups: lineups,
    formations: formations,
    coaches: coaches,
    pressure: pressure,
  );
}

final List<FixtureEvent> _matchEvents = [
  FixtureEvent(
    eventId: 1,
    teamId: _fixture.homeTeamId,
    eventTypeId: 14,
    eventTypeCode: 'goal',
    eventTypeName: 'Goal',
    playerId: 101,
    playerName: 'Home Starter',
    playerImage: null,
    relatedPlayerId: 102,
    relatedPlayerName: 'Home Keeper',
    relatedPlayerImage: null,
    minute: 45,
    extraMinute: 2,
    onBench: false,
  ),
  FixtureEvent(
    eventId: 2,
    teamId: _fixture.awayTeamId,
    eventTypeId: 20,
    eventTypeCode: 'redcard',
    eventTypeName: 'Red Card',
    playerId: 201,
    playerName: 'Away Defender',
    playerImage: null,
    relatedPlayerId: null,
    relatedPlayerName: null,
    relatedPlayerImage: null,
    minute: 70,
    extraMinute: null,
    onBench: false,
  ),
  FixtureEvent(
    eventId: 3,
    teamId: _fixture.awayTeamId,
    eventTypeId: 18,
    eventTypeCode: 'substitution',
    eventTypeName: 'Substitution',
    playerId: 202,
    playerName: 'Away Substitute',
    playerImage: null,
    relatedPlayerId: 203,
    relatedPlayerName: 'Away Starter',
    relatedPlayerImage: null,
    minute: 75,
    extraMinute: null,
    onBench: true,
  ),
  FixtureEvent(
    eventId: 4,
    teamId: _fixture.homeTeamId,
    eventTypeId: 18,
    eventTypeCode: 'substitution',
    eventTypeName: 'Substitution',
    playerId: 104,
    playerName: 'Home Substitute',
    playerImage: null,
    relatedPlayerId: 101,
    relatedPlayerName: 'Home Starter',
    relatedPlayerImage: null,
    minute: 80,
    extraMinute: null,
    onBench: true,
  ),
];

final List<FixtureLineupEntry> _lineups = [
  _lineupEntry(
    teamId: _fixture.homeTeamId,
    playerId: 102,
    playerName: 'Home Keeper',
    formationField: '1:1',
    jerseyNumber: 1,
  ),
  _lineupEntry(
    teamId: _fixture.homeTeamId,
    playerId: 101,
    playerName: 'Home Starter',
    formationField: '4:1',
    jerseyNumber: 9,
  ),
  _lineupEntry(
    teamId: _fixture.homeTeamId,
    playerId: 104,
    playerName: 'Home Substitute',
    formationField: null,
    jerseyNumber: 14,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 200,
    playerName: 'Away Keeper',
    formationField: '1:1',
    jerseyNumber: 1,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 201,
    playerName: 'Away Defender',
    formationField: '2:1',
    jerseyNumber: 4,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 203,
    playerName: 'Away Starter',
    formationField: '4:1',
    jerseyNumber: 9,
  ),
  _lineupEntry(
    teamId: _fixture.awayTeamId,
    playerId: 202,
    playerName: 'Away Substitute',
    formationField: null,
    jerseyNumber: 12,
  ),
];

FixtureLineupEntry _lineupEntry({
  required int teamId,
  required int playerId,
  required String playerName,
  required String? formationField,
  required int jerseyNumber,
}) {
  return FixtureLineupEntry(
    teamId: teamId,
    playerId: playerId,
    playerName: playerName,
    playerImage: null,
    positionId: null,
    lineupTypeId: formationField == null ? 12 : 11,
    formationField: formationField,
    jerseyNumber: jerseyNumber,
    minutesPlayed: null,
    rating: null,
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
