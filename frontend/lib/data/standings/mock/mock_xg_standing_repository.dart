import 'package:flutter/foundation.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class MockXgStandingRepository implements XgStandingRepository {
  MockXgStandingRepository({List<XgStanding>? standings})
      : _allXgStandings = List.unmodifiable(standings ?? mockXgStandings) {
    final byCompetition = <int, List<XgStanding>>{};
    for (final standing in _allXgStandings) {
      byCompetition.putIfAbsent(standing.competitionId, () => []).add(standing);
    }
    _standingsByCompetition = Map.unmodifiable({
      for (final entry in byCompetition.entries)
        entry.key: List<XgStanding>.unmodifiable(entry.value),
    });
    _xgStandings = ValueNotifier(_allXgStandings);
  }

  final List<XgStanding> _allXgStandings;
  late final Map<int, List<XgStanding>> _standingsByCompetition;
  late final ValueNotifier<List<XgStanding>> _xgStandings;

  @override
  List<XgStanding> get allXgStandings => _allXgStandings;

  @override
  ValueListenable<List<XgStanding>> get xgStandings => _xgStandings;

  @override
  List<XgStanding> forCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final matches = (_standingsByCompetition[competitionId] ?? const [])
        .where(
          (standing) => seasonId == null || standing.seasonId == seasonId,
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
  XgStanding? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
  }) {
    for (final standing in forCompetition(
      competitionId,
      seasonId: seasonId,
    )) {
      if (standing.teamId == teamId) return standing;
    }
    return null;
  }

  @override
  Future<void> initialize() async {}
}
