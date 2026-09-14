import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_injury_report.dart';

abstract interface class TeamInjuryRepository {
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports;

  TeamInjuryReport? cachedForTeam(int teamId);

  Future<TeamInjuryReport> loadForTeam(int teamId);
}
