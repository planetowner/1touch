import 'package:flutter/foundation.dart';

@immutable
class TeamPlayerContract {
  const TeamPlayerContract({
    required this.playerId,
    required this.playerName,
    this.playerImage,
    this.jerseyNumber,
    this.startDate,
    this.endDate,
  });

  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? jerseyNumber;

  /// Provider contract boundaries. Either date may be unavailable.
  final DateTime? startDate;
  final DateTime? endDate;
}

@immutable
class TeamContractRoster {
  TeamContractRoster({
    required this.teamId,
    required this.seasonId,
    required List<TeamPlayerContract> players,
  }) : players = List.unmodifiable(players);

  final int teamId;
  final int seasonId;
  final List<TeamPlayerContract> players;
}
