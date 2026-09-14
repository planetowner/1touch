import 'package:flutter/foundation.dart';

@immutable
class TeamPlayerInjury {
  const TeamPlayerInjury({
    required this.sidelineId,
    required this.typeId,
    required this.typeName,
    this.startDate,
    this.endDate,
  });

  final int sidelineId;
  final int typeId;
  final String typeName;

  /// Provider-supplied injury period boundaries.
  ///
  /// [endDate] is not a confirmed return date and must not be converted into
  /// an estimated "weeks remaining" label.
  final DateTime? startDate;
  final DateTime? endDate;
}

@immutable
class InjuredTeamPlayer {
  InjuredTeamPlayer({
    required this.playerId,
    required this.playerName,
    this.playerImage,
    this.jerseyNumber,
    required List<TeamPlayerInjury> injuries,
  }) : injuries = List.unmodifiable(injuries);

  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? jerseyNumber;
  final List<TeamPlayerInjury> injuries;
}

@immutable
class TeamInjuryReport {
  TeamInjuryReport({
    required this.teamId,
    required this.seasonId,
    required List<InjuredTeamPlayer> players,
  }) : players = List.unmodifiable(players);

  final int teamId;
  final int seasonId;
  final List<InjuredTeamPlayer> players;
}
