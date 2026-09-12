import 'package:flutter/foundation.dart';
import 'package:onetouch/models/standing.dart';

abstract interface class StandingRepository {
  List<Standing> get allStandings;

  ValueListenable<List<Standing>> get standings;

  List<Standing> forCompetition(
    int competitionId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  });

  Standing? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  });

  Future<void> initialize();
}
