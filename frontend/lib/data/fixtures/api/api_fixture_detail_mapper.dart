import 'package:onetouch/data/fixtures/api/api_fixture_detail_response.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/models/fixture_detail.dart';

FixtureDetail fixtureDetailFromApiResponse(
  ApiFixtureDetailResponse response,
) {
  final expectedGoals = response.expectedGoals;

  return FixtureDetail(
    fixture: fixtureFromApiResponse(response.fixture),
    venueName: response.venueName,
    expectedGoals: expectedGoals == null
        ? null
        : FixtureExpectedGoals(
            homeXg: expectedGoals.homeXg,
            awayXg: expectedGoals.awayXg,
            homeXga: expectedGoals.homeXga,
            awayXga: expectedGoals.awayXga,
            provider: expectedGoals.provider,
          ),
    playerExpectedGoals: response.playerExpectedGoals
        .map(
          (item) => FixturePlayerExpectedGoal(
            playerId: item.playerId,
            playerName: item.playerName,
            xg: item.xg,
          ),
        )
        .toList(growable: false),
    shots: response.shots
        .map(
          (item) => FixtureShot(
            shotId: item.shotId,
            teamId: item.teamId,
            playerId: item.playerId,
            playerName: item.playerName,
            minute: item.minute,
            x: item.x,
            y: item.y,
            xg: item.xg,
            result: item.result,
          ),
        )
        .toList(growable: false),
    events: response.events
        .map(
          (item) => FixtureEvent(
            eventId: item.eventId,
            teamId: item.teamId,
            eventTypeId: item.eventTypeId,
            eventTypeCode: item.eventTypeCode,
            eventTypeName: item.eventTypeName,
            playerId: item.playerId,
            playerName: item.playerName,
            playerImage: item.playerImage,
            relatedPlayerId: item.relatedPlayerId,
            relatedPlayerName: item.relatedPlayerName,
            relatedPlayerImage: item.relatedPlayerImage,
            minute: item.minute,
            extraMinute: item.extraMinute,
            onBench: item.onBench,
          ),
        )
        .toList(growable: false),
    statistics: response.statistics
        .map(
          (item) => FixtureStatistic(
            teamId: item.teamId,
            statTypeId: item.statTypeId,
            statCode: item.statCode,
            statName: item.statName,
            value: item.value,
          ),
        )
        .toList(growable: false),
    lineups: response.lineups
        .map(
          (item) => FixtureLineupEntry(
            teamId: item.teamId,
            playerId: item.playerId,
            playerName: item.playerName,
            playerImage: item.playerImage,
            positionId: item.positionId,
            lineupTypeId: item.lineupTypeId,
            formationField: item.formationField,
            jerseyNumber: item.jerseyNumber,
            minutesPlayed: item.minutesPlayed,
            rating: item.rating,
          ),
        )
        .toList(growable: false),
    formations: response.formations
        .map(
          (item) => FixtureFormation(
            teamId: item.teamId,
            formation: item.formation,
          ),
        )
        .toList(growable: false),
    coaches: response.coaches
        .map(
          (item) => FixtureCoach(
            teamId: item.teamId,
            coachId: item.coachId,
            name: item.name,
          ),
        )
        .toList(growable: false),
    pressure: response.pressure
        .map(
          (item) => FixturePressurePoint(
            teamId: item.teamId,
            minute: item.minute,
            pressure: item.pressure,
          ),
        )
        .toList(growable: false),
  );
}
