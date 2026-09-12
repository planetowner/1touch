import 'package:flutter/foundation.dart';
import 'package:onetouch/models/standing.dart';

abstract interface class XgStandingRepository {
  List<XgStanding> get allXgStandings;

  ValueListenable<List<XgStanding>> get xgStandings;

  List<XgStanding> forCompetition(
    int competitionId, {
    int? seasonId,
  });

  XgStanding? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
  });

  Future<void> initialize();
}
