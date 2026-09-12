import 'package:flutter/foundation.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class MockStandingRepository implements StandingRepository {
  MockStandingRepository({List<Standing>? standings})
      : _allStandings = List.unmodifiable(standings ?? mockStandings) {
    final byCompetition = <int, List<Standing>>{};
    for (final standing in _allStandings) {
      byCompetition.putIfAbsent(standing.competitionId, () => []).add(standing);
    }
    _standingsByCompetition = Map.unmodifiable({
      for (final entry in byCompetition.entries)
        entry.key: List<Standing>.unmodifiable(entry.value),
    });
    _standings = ValueNotifier(_allStandings);
  }

  final List<Standing> _allStandings;
  late final Map<int, List<Standing>> _standingsByCompetition;
  late final ValueNotifier<List<Standing>> _standings;

  @override
  List<Standing> get allStandings => _allStandings;

  @override
  ValueListenable<List<Standing>> get standings => _standings;

  @override
  List<Standing> forCompetition(
    int competitionId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  }) {
    final matches = (_standingsByCompetition[competitionId] ?? const [])
        .where(
          (standing) =>
              (seasonId == null || standing.seasonId == seasonId) &&
              (phase == null || standing.phase == phase) &&
              (groupName == null || standing.groupName == groupName),
        )
        .toList()
      ..sort((a, b) {
        final positionComparison = a.position.compareTo(b.position);
        if (positionComparison != 0) return positionComparison;
        return a.teamId.compareTo(b.teamId);
      });
    return List.unmodifiable(matches);
  }

  @override
  Standing? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  }) {
    for (final standing in forCompetition(
      competitionId,
      seasonId: seasonId,
      phase: phase,
      groupName: groupName,
    )) {
      if (standing.teamId == teamId) return standing;
    }
    return null;
  }

  @override
  Future<void> initialize() async {}
}
