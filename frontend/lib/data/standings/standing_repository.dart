import 'package:flutter/foundation.dart';
import 'package:onetouch/models/standing.dart';

@immutable
class StandingQuery {
  const StandingQuery({
    required this.competitionId,
    this.seasonId,
  });

  final int competitionId;
  final int? seasonId;

  @override
  bool operator ==(Object other) {
    return other is StandingQuery &&
        other.competitionId == competitionId &&
        other.seasonId == seasonId;
  }

  @override
  int get hashCode => Object.hash(competitionId, seasonId);
}

abstract interface class StandingRepository {
  List<Standing> get allStandings;

  ValueListenable<List<Standing>> get standings;

  ValueListenable<Map<StandingQuery, List<Standing>>> get cachedTables;

  List<Standing>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  });

  Future<List<Standing>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  });

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
