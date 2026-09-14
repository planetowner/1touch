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
    _cachedTables = ValueNotifier(Map.unmodifiable({
      for (final standing in _allStandings)
        StandingQuery(
          competitionId: standing.competitionId,
          seasonId: standing.seasonId,
        ): List<Standing>.unmodifiable(
          _allStandings.where(
            (candidate) =>
                candidate.competitionId == standing.competitionId &&
                candidate.seasonId == standing.seasonId,
          ),
        ),
    }));
  }

  final List<Standing> _allStandings;
  late final Map<int, List<Standing>> _standingsByCompetition;
  late final ValueNotifier<List<Standing>> _standings;
  late final ValueNotifier<Map<StandingQuery, List<Standing>>> _cachedTables;

  @override
  List<Standing> get allStandings => _allStandings;

  @override
  ValueListenable<List<Standing>> get standings => _standings;

  @override
  ValueListenable<Map<StandingQuery, List<Standing>>> get cachedTables =>
      _cachedTables;

  @override
  List<Standing>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    if (seasonId == null) {
      final matches = forCompetition(competitionId);
      return matches.isEmpty ? null : matches;
    }
    return _cachedTables
        .value[StandingQuery(competitionId: competitionId, seasonId: seasonId)];
  }

  @override
  Future<List<Standing>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) async {
    return cachedForCompetition(competitionId, seasonId: seasonId) ?? const [];
  }

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
