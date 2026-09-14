import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_overview.dart';

abstract interface class TeamOverviewRepository {
  ValueListenable<Map<int, TeamOverview>> get cachedTeams;

  TeamOverview? cachedForTeam(int teamId);

  Future<TeamOverview> loadForTeam(int teamId);
}
