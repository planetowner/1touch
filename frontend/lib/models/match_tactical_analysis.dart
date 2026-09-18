import 'package:flutter/foundation.dart';

@immutable
class TacticalPitchPoint {
  const TacticalPitchPoint({required this.x, required this.y});

  final double x;
  final double y;
}

@immutable
class MatchAttackMetrics {
  const MatchAttackMetrics({
    required this.keyPasses,
    required this.completedPassesIntoFinalThird,
  });

  final int keyPasses;
  final int completedPassesIntoFinalThird;
}

@immutable
class MatchProgressionChannel {
  const MatchProgressionChannel({
    required this.channel,
    required this.count,
    required this.percentage,
  });

  final String channel;
  final int count;
  final double? percentage;
}

@immutable
class MatchProgressionMetrics {
  MatchProgressionMetrics({
    required this.completedPasses,
    required this.progressivePasses,
    required List<MatchProgressionChannel> channels,
  }) : channels = List.unmodifiable(channels);

  final int completedPasses;
  final int progressivePasses;
  final List<MatchProgressionChannel> channels;
}

@immutable
class MatchDefensiveActivity {
  MatchDefensiveActivity({
    required this.complete,
    required this.missingPositionCount,
    required this.actionCount,
    required List<TacticalPitchPoint> actions,
    required this.recoveries,
    required this.highRegains,
    required this.ownHalfPercentage,
    required this.opponentHalfPercentage,
    required this.averageRegainX,
    required this.averageRegainHeightMetres,
  }) : actions = List.unmodifiable(actions);

  final bool complete;
  final int missingPositionCount;
  final int actionCount;
  final List<TacticalPitchPoint> actions;
  final int? recoveries;
  final int? highRegains;
  final double? ownHalfPercentage;
  final double? opponentHalfPercentage;
  final double? averageRegainX;
  final double? averageRegainHeightMetres;
}

@immutable
class MatchTeamTacticalAnalysis {
  const MatchTeamTacticalAnalysis({
    required this.teamId,
    required this.attack,
    required this.progression,
    required this.defensiveActivity,
  });

  final int teamId;
  final MatchAttackMetrics attack;
  final MatchProgressionMetrics progression;
  final MatchDefensiveActivity defensiveActivity;
}

@immutable
class MatchTacticalAnalysis {
  const MatchTacticalAnalysis({
    required this.fixtureId,
    required this.available,
    required this.home,
    required this.away,
  });

  final int fixtureId;
  final bool available;
  final MatchTeamTacticalAnalysis? home;
  final MatchTeamTacticalAnalysis? away;
}

@immutable
class MatchShot {
  const MatchShot({
    required this.eventId,
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.minute,
    required this.extraMinute,
    required this.result,
    required this.start,
    required this.end,
  });

  final String eventId;
  final int teamId;
  final int? playerId;
  final String? playerName;
  final int minute;
  final int? extraMinute;
  final String result;
  final TacticalPitchPoint start;
  final TacticalPitchPoint end;
}

@immutable
class MatchShotMap {
  MatchShotMap({
    required this.fixtureId,
    required this.available,
    required this.homeCount,
    required this.awayCount,
    required List<MatchShot> shots,
  }) : shots = List.unmodifiable(shots);

  final int fixtureId;
  final bool available;
  final int? homeCount;
  final int? awayCount;
  final List<MatchShot> shots;
}
