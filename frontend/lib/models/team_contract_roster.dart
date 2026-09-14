import 'package:flutter/foundation.dart';

enum TeamPositionGroup {
  goalkeeper(24),
  defender(25),
  midfielder(26),
  forward(27);

  const TeamPositionGroup(this.apiId);

  final int apiId;
}

enum TeamLeadershipRole {
  captain,
  viceCaptain,
}

@immutable
class TeamPlayerContract {
  const TeamPlayerContract({
    required this.playerId,
    required this.playerName,
    this.playerImage,
    this.positionGroup,
    this.jerseyNumber,
    this.dateOfBirth,
    this.estimatedWeeklyGrossEur,
    this.leadershipRole,
    this.startDate,
    this.endDate,
  });

  final int playerId;
  final String playerName;
  final String? playerImage;
  final TeamPositionGroup? positionGroup;
  final int? jerseyNumber;
  final DateTime? dateOfBirth;
  final int? estimatedWeeklyGrossEur;
  final TeamLeadershipRole? leadershipRole;

  /// Provider contract boundaries. Either date may be unavailable.
  final DateTime? startDate;
  final DateTime? endDate;
}

@immutable
class TeamContractRoster {
  TeamContractRoster({
    required this.teamId,
    required this.seasonId,
    required this.isCurrent,
    required List<TeamPlayerContract> players,
  }) : players = List.unmodifiable(players);

  final int teamId;
  final int seasonId;
  final bool isCurrent;
  final List<TeamPlayerContract> players;
}
