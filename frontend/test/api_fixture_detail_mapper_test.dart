import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_detail_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_detail_response.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  group('fixtureDetailFromApiResponse', () {
    test('maps the base fixture and every detail collection', () {
      final detail = fixtureDetailFromApiResponse(_fullResponse());

      expect(detail.fixture.fixtureId, 19712345);
      expect(detail.fixture.competitionType, CompetitionType.league);
      expect(detail.fixture.status, FixtureStatus.past);
      expect(detail.venueName, 'Anfield');

      final expectedGoals = detail.expectedGoals!;
      expect(expectedGoals.homeXg, 1.75);
      expect(expectedGoals.awayXg, 0.82);
      expect(expectedGoals.homeXga, 0.82);
      expect(expectedGoals.awayXga, 1.75);
      expect(expectedGoals.provider, 'understat');

      final playerXg = detail.playerExpectedGoals.single;
      expect(playerXg.playerId, 101);
      expect(playerXg.playerName, 'Home Striker');
      expect(playerXg.xg, 0.64);

      final shot = detail.shots.single;
      expect(shot.shotId, 501);
      expect(shot.teamId, 8);
      expect(shot.playerId, 101);
      expect(shot.playerName, 'Home Striker');
      expect(shot.minute, 27);
      expect(shot.x, 0.91);
      expect(shot.y, 0.48);
      expect(shot.xg, 0.38);
      expect(shot.result, 'Goal');

      final event = detail.events.single;
      expect(event.eventId, 601);
      expect(event.teamId, 8);
      expect(event.eventTypeId, 14);
      expect(event.eventTypeCode, 'goal');
      expect(event.eventTypeName, 'Goal');
      expect(event.playerId, 101);
      expect(event.playerName, 'Home Striker');
      expect(event.playerImage, 'https://cdn.example/101.png');
      expect(event.relatedPlayerId, 102);
      expect(event.relatedPlayerName, 'Home Winger');
      expect(event.relatedPlayerImage, 'https://cdn.example/102.png');
      expect(event.minute, 27);
      expect(event.extraMinute, 1);
      expect(event.onBench, isFalse);

      final statistic = detail.statistics.single;
      expect(statistic.teamId, 8);
      expect(statistic.statTypeId, 55);
      expect(statistic.statCode, 'shots-on-target');
      expect(statistic.statName, 'Shots On Target');
      expect(statistic.value, 7.0);

      final lineup = detail.lineups.single;
      expect(lineup.teamId, 8);
      expect(lineup.playerId, 101);
      expect(lineup.playerName, 'Home Striker');
      expect(lineup.playerImage, 'https://cdn.example/101.png');
      expect(lineup.positionId, 27);
      expect(lineup.lineupTypeId, 11);
      expect(lineup.formationField, '4:3');
      expect(lineup.jerseyNumber, 9);
      expect(lineup.minutesPlayed, 90);
      expect(lineup.rating, 8.4);

      final formation = detail.formations.single;
      expect(formation.teamId, 8);
      expect(formation.formation, '4-3-3');

      final coach = detail.coaches.single;
      expect(coach.teamId, 8);
      expect(coach.coachId, 701);
      expect(coach.name, 'Home Coach');

      final pressure = detail.pressure.single;
      expect(pressure.teamId, 8);
      expect(pressure.minute, 27);
      expect(pressure.pressure, 0.78);
    });

    test('preserves nullable fields and empty collections', () {
      final detail = fixtureDetailFromApiResponse(
        ApiFixtureDetailResponse(
          fixture: _fixtureResponse(status: null),
          venueName: null,
          expectedGoals: null,
          playerExpectedGoals: const [],
          shots: const [],
          events: const [
            ApiFixtureEventResponse(
              eventId: 602,
              teamId: 19,
              eventTypeId: 18,
              eventTypeCode: 'substitution',
              eventTypeName: 'Substitution',
              playerId: null,
              playerName: null,
              playerImage: null,
              relatedPlayerId: null,
              relatedPlayerName: null,
              relatedPlayerImage: null,
              minute: 73,
              extraMinute: null,
              onBench: null,
            ),
          ],
          statistics: const [],
          lineups: const [
            ApiFixtureLineupResponse(
              teamId: 19,
              playerId: 201,
              playerName: 'Away Player',
              playerImage: null,
              positionId: null,
              lineupTypeId: 12,
              formationField: null,
              jerseyNumber: null,
              minutesPlayed: null,
              rating: null,
            ),
          ],
          formations: const [],
          coaches: const [],
          pressure: const [],
        ),
      );

      expect(detail.fixture.status, FixtureStatus.unknown);
      expect(detail.venueName, isNull);
      expect(detail.expectedGoals, isNull);
      expect(detail.playerExpectedGoals, isEmpty);
      expect(detail.shots, isEmpty);
      expect(detail.statistics, isEmpty);
      expect(detail.formations, isEmpty);
      expect(detail.coaches, isEmpty);
      expect(detail.pressure, isEmpty);

      final event = detail.events.single;
      expect(event.playerId, isNull);
      expect(event.playerName, isNull);
      expect(event.playerImage, isNull);
      expect(event.relatedPlayerId, isNull);
      expect(event.relatedPlayerName, isNull);
      expect(event.relatedPlayerImage, isNull);
      expect(event.extraMinute, isNull);
      expect(event.onBench, isNull);

      final lineup = detail.lineups.single;
      expect(lineup.playerImage, isNull);
      expect(lineup.positionId, isNull);
      expect(lineup.formationField, isNull);
      expect(lineup.jerseyNumber, isNull);
      expect(lineup.minutesPlayed, isNull);
      expect(lineup.rating, isNull);
    });

    test('returns immutable detail collections', () {
      final detail = fixtureDetailFromApiResponse(_fullResponse());

      expect(
        () => detail.shots.add(detail.shots.single),
        throwsUnsupportedError,
      );
      expect(
        () => detail.events.clear(),
        throwsUnsupportedError,
      );
    });
  });
}

ApiFixtureDetailResponse _fullResponse() {
  return ApiFixtureDetailResponse(
    fixture: _fixtureResponse(),
    venueName: 'Anfield',
    expectedGoals: const ApiFixtureExpectedGoalsResponse(
      homeXg: 1.75,
      awayXg: 0.82,
      homeXga: 0.82,
      awayXga: 1.75,
      provider: 'understat',
    ),
    playerExpectedGoals: const [
      ApiFixturePlayerExpectedGoalResponse(
        playerId: 101,
        playerName: 'Home Striker',
        xg: 0.64,
      ),
    ],
    shots: const [
      ApiFixtureShotResponse(
        shotId: 501,
        teamId: 8,
        playerId: 101,
        playerName: 'Home Striker',
        minute: 27,
        x: 0.91,
        y: 0.48,
        xg: 0.38,
        result: 'Goal',
      ),
    ],
    events: const [
      ApiFixtureEventResponse(
        eventId: 601,
        teamId: 8,
        eventTypeId: 14,
        eventTypeCode: 'goal',
        eventTypeName: 'Goal',
        playerId: 101,
        playerName: 'Home Striker',
        playerImage: 'https://cdn.example/101.png',
        relatedPlayerId: 102,
        relatedPlayerName: 'Home Winger',
        relatedPlayerImage: 'https://cdn.example/102.png',
        minute: 27,
        extraMinute: 1,
        onBench: false,
      ),
    ],
    statistics: const [
      ApiFixtureStatisticResponse(
        teamId: 8,
        statTypeId: 55,
        statCode: 'shots-on-target',
        statName: 'Shots On Target',
        value: 7,
      ),
    ],
    lineups: const [
      ApiFixtureLineupResponse(
        teamId: 8,
        playerId: 101,
        playerName: 'Home Striker',
        playerImage: 'https://cdn.example/101.png',
        positionId: 27,
        lineupTypeId: 11,
        formationField: '4:3',
        jerseyNumber: 9,
        minutesPlayed: 90,
        rating: 8.4,
      ),
    ],
    formations: const [
      ApiFixtureFormationResponse(teamId: 8, formation: '4-3-3'),
    ],
    coaches: const [
      ApiFixtureCoachResponse(teamId: 8, coachId: 701, name: 'Home Coach'),
    ],
    pressure: const [
      ApiFixturePressureResponse(teamId: 8, minute: 27, pressure: 0.78),
    ],
  );
}

ApiFixtureResponse _fixtureResponse({String? status = 'past'}) {
  return ApiFixtureResponse(
    fixtureId: 19712345,
    competitionId: 8,
    seasonId: 25583,
    competitionType: 'league',
    roundName: '3',
    stageId: 77432101,
    stageName: 'Regular Season',
    roundId: 375001,
    groupId: null,
    aggregateId: null,
    leg: '1/1',
    venueId: 206,
    stateId: 5,
    stateCode: 'FT',
    stateName: 'Finished',
    status: status,
    startingAt: '2026-08-29 14:00:00',
    homeTeamId: 8,
    awayTeamId: 19,
    homeScore: 2,
    awayScore: 1,
    homePenaltyScore: null,
    awayPenaltyScore: null,
    homeTeamName: 'Liverpool',
    awayTeamName: 'Arsenal',
    homeTeamLogo: 'https://cdn.example/liverpool.png',
    awayTeamLogo: 'https://cdn.example/arsenal.png',
  );
}
