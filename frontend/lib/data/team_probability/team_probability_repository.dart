import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_probability.dart';

@immutable
class TeamProbabilityQuery {
  const TeamProbabilityQuery({required this.teamId, this.seasonId});

  final int teamId;
  final int? seasonId;

  @override
  bool operator ==(Object other) {
    return other is TeamProbabilityQuery &&
        other.teamId == teamId &&
        other.seasonId == seasonId;
  }

  @override
  int get hashCode => Object.hash(teamId, seasonId);
}

abstract interface class TeamProbabilityRepository {
  ValueListenable<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      get cachedSnapshots;

  TeamProbabilitySnapshot? cachedForTeam(int teamId, {int? seasonId});

  Future<TeamProbabilitySnapshot> loadForTeam(
    int teamId, {
    int? seasonId,
  });
}
