import 'package:flutter/foundation.dart';

@immutable
class TeamCompetitionContext {
  const TeamCompetitionContext({
    required this.teamId,
    this.seasonId,
    this.competitionId,
    this.competitionName,
    this.currentPosition,
  });

  final int teamId;
  final int? seasonId;
  final int? competitionId;
  final String? competitionName;
  final int? currentPosition;
}

abstract interface class TeamCompetitionContextResolver {
  TeamCompetitionContext? resolve(int teamId);
}
