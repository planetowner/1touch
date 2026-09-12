import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture.dart';

@immutable
class FixtureDetail {
  FixtureDetail({
    required this.fixture,
    required this.venueName,
    required this.expectedGoals,
    required List<FixturePlayerExpectedGoal> playerExpectedGoals,
    required List<FixtureShot> shots,
    required List<FixtureEvent> events,
    required List<FixtureStatistic> statistics,
    required List<FixtureLineupEntry> lineups,
    required List<FixtureFormation> formations,
    required List<FixtureCoach> coaches,
    required List<FixturePressurePoint> pressure,
  })  : playerExpectedGoals = List.unmodifiable(playerExpectedGoals),
        shots = List.unmodifiable(shots),
        events = List.unmodifiable(events),
        statistics = List.unmodifiable(statistics),
        lineups = List.unmodifiable(lineups),
        formations = List.unmodifiable(formations),
        coaches = List.unmodifiable(coaches),
        pressure = List.unmodifiable(pressure);

  final Fixture fixture;
  final String? venueName;
  final FixtureExpectedGoals? expectedGoals;
  final List<FixturePlayerExpectedGoal> playerExpectedGoals;
  final List<FixtureShot> shots;
  final List<FixtureEvent> events;
  final List<FixtureStatistic> statistics;
  final List<FixtureLineupEntry> lineups;
  final List<FixtureFormation> formations;
  final List<FixtureCoach> coaches;
  final List<FixturePressurePoint> pressure;
}

@immutable
class FixtureExpectedGoals {
  const FixtureExpectedGoals({
    required this.homeXg,
    required this.awayXg,
    required this.homeXga,
    required this.awayXga,
    required this.provider,
  });

  final double homeXg;
  final double awayXg;
  final double homeXga;
  final double awayXga;
  final String provider;
}

@immutable
class FixturePlayerExpectedGoal {
  const FixturePlayerExpectedGoal({
    required this.playerId,
    required this.playerName,
    required this.xg,
  });

  final int playerId;
  final String playerName;
  final double xg;
}

@immutable
class FixtureShot {
  const FixtureShot({
    required this.shotId,
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.minute,
    required this.x,
    required this.y,
    required this.xg,
    required this.result,
  });

  final int shotId;
  final int teamId;
  final int playerId;
  final String playerName;
  final int minute;
  final double x;
  final double y;
  final double xg;
  final String result;
}

@immutable
class FixtureEvent {
  const FixtureEvent({
    required this.eventId,
    required this.teamId,
    required this.eventTypeId,
    required this.eventTypeCode,
    required this.eventTypeName,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.relatedPlayerId,
    required this.relatedPlayerName,
    required this.relatedPlayerImage,
    required this.minute,
    required this.extraMinute,
    required this.onBench,
  });

  final int eventId;
  final int teamId;
  final int eventTypeId;
  final String eventTypeCode;
  final String eventTypeName;
  final int? playerId;
  final String? playerName;
  final String? playerImage;
  final int? relatedPlayerId;
  final String? relatedPlayerName;
  final String? relatedPlayerImage;
  final int minute;
  final int? extraMinute;
  final bool? onBench;
}

@immutable
class FixtureStatistic {
  const FixtureStatistic({
    required this.teamId,
    required this.statTypeId,
    required this.statCode,
    required this.statName,
    required this.value,
  });

  final int teamId;
  final int statTypeId;
  final String statCode;
  final String statName;
  final double value;
}

@immutable
class FixtureLineupEntry {
  const FixtureLineupEntry({
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.positionId,
    required this.lineupTypeId,
    required this.formationField,
    required this.jerseyNumber,
    required this.minutesPlayed,
    required this.rating,
  });

  final int teamId;
  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? positionId;
  final int lineupTypeId;
  final String? formationField;
  final int? jerseyNumber;
  final int? minutesPlayed;
  final double? rating;
}

@immutable
class FixtureFormation {
  const FixtureFormation({
    required this.teamId,
    required this.formation,
  });

  final int teamId;
  final String formation;
}

@immutable
class FixtureCoach {
  const FixtureCoach({
    required this.teamId,
    required this.coachId,
    required this.name,
  });

  final int teamId;
  final int coachId;
  final String name;
}

@immutable
class FixturePressurePoint {
  const FixturePressurePoint({
    required this.teamId,
    required this.minute,
    required this.pressure,
  });

  final int teamId;
  final int minute;
  final double pressure;
}
