import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_contract_roster.dart';

@immutable
class TeamContractQuery {
  const TeamContractQuery({
    required this.teamId,
    this.seasonId,
  });

  final int teamId;
  final int? seasonId;

  @override
  bool operator ==(Object other) {
    return other is TeamContractQuery &&
        other.teamId == teamId &&
        other.seasonId == seasonId;
  }

  @override
  int get hashCode => Object.hash(teamId, seasonId);
}

abstract interface class TeamContractRepository {
  ValueListenable<Map<TeamContractQuery, TeamContractRoster>> get cachedRosters;

  TeamContractRoster? cachedForTeam(
    int teamId, {
    int? seasonId,
  });

  Future<TeamContractRoster> loadForTeam(
    int teamId, {
    int? seasonId,
  });
}
