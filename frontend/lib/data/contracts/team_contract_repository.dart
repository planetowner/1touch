import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_contract_roster.dart';

abstract interface class TeamContractRepository {
  ValueListenable<Map<int, TeamContractRoster>> get cachedRosters;

  TeamContractRoster? cachedForTeam(int teamId);

  Future<TeamContractRoster> loadForTeam(int teamId);
}
