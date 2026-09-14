import 'package:flutter/foundation.dart';
import 'package:onetouch/models/standing.dart';

@immutable
class XgStandingQuery {
  const XgStandingQuery({
    required this.competitionId,
    this.seasonId,
  });

  final int competitionId;
  final int? seasonId;

  @override
  bool operator ==(Object other) {
    return other is XgStandingQuery &&
        other.competitionId == competitionId &&
        other.seasonId == seasonId;
  }

  @override
  int get hashCode => Object.hash(competitionId, seasonId);
}

abstract interface class XgStandingRepository {
  List<XgStanding> get allXgStandings;

  ValueListenable<List<XgStanding>> get xgStandings;

  ValueListenable<Map<XgStandingQuery, List<XgStanding>>> get cachedTables;

  List<XgStanding>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  });

  Future<List<XgStanding>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  });

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
