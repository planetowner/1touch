import 'package:flutter/foundation.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_overview.dart';

class TestTeamOverviewRepository implements TeamOverviewRepository {
  TestTeamOverviewRepository({
    Map<int, TeamOverview>? initial,
    this.loader,
  }) : _cached = ValueNotifier(Map.unmodifiable(initial ?? const {}));

  factory TestTeamOverviewRepository.withTeam9() {
    final overview = testTeamOverview(teamId: 9);
    return TestTeamOverviewRepository(initial: {9: overview});
  }

  final Future<TeamOverview> Function(int teamId)? loader;
  final ValueNotifier<Map<int, TeamOverview>> _cached;
  final List<int> requestedTeamIds = [];

  @override
  ValueListenable<Map<int, TeamOverview>> get cachedTeams => _cached;

  @override
  TeamOverview? cachedForTeam(int teamId) => _cached.value[teamId];

  @override
  Future<TeamOverview> loadForTeam(int teamId) async {
    requestedTeamIds.add(teamId);
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;
    final load = loader;
    if (load == null) throw StateError('No test Team overview for $teamId.');
    final overview = await load(teamId);
    _cached.value = Map.unmodifiable({..._cached.value, teamId: overview});
    return overview;
  }
}

TeamOverview testTeamOverview({
  int teamId = 9,
  String name = 'Manchester City',
  int nextCompetitionId = 8,
  CompetitionType nextCompetitionType = CompetitionType.league,
}) {
  return TeamOverview(
    id: teamId,
    name: name,
    shortName: 'MCI',
    imagePath: 'https://cdn.example/$teamId.png',
    standing: {
      'position': 1,
      'rank_delta': 0,
      'team_id': teamId,
      'matches_played': 3,
      'won': 3,
      'draw': 0,
      'lost': 0,
      'goals_for': 8,
      'goals_against': 2,
      'goal_diff': 6,
      'points': 9,
      'last5_form': ['W', 'W', 'W'],
    },
    nextMatch: Fixture(
      fixtureId: 1001,
      seasonId: 25583,
      competitionId: nextCompetitionId,
      homeTeamId: teamId,
      awayTeamId: 19,
      competitionType: nextCompetitionType,
      roundName: '4',
      status: FixtureStatus.upcoming,
      startingAt: '2026-09-20T15:00:00.000Z',
    ),
    lastMatch: Fixture(
      fixtureId: 1000,
      seasonId: 25583,
      competitionId: 8,
      homeTeamId: 19,
      awayTeamId: teamId,
      competitionType: CompetitionType.league,
      roundName: '3',
      status: FixtureStatus.past,
      startingAt: '2026-09-13T15:00:00.000Z',
      homeScore: 1,
      awayScore: 2,
    ),
  );
}
