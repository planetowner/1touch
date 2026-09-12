import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_trophies/team_trophy_repository.dart';
import 'package:onetouch/models/team_trophy.dart';

void teamTrophyRepositoryContract({
  required TeamTrophyRepository Function(List<TeamTrophy> trophies)
      createRepository,
}) {
  const trophies = [
    TeamTrophy(
      id: 'alpha-league-24-25',
      teamId: 1,
      seasonLabel: '24/25',
      name: 'League',
      competitionCode: 'LEAGUE',
      type: TeamTrophyType.domesticLeague,
    ),
    TeamTrophy(
      id: 'alpha-cup-24-25',
      teamId: 1,
      seasonLabel: '24/25',
      name: 'Cup',
      competitionCode: 'CUP',
      type: TeamTrophyType.domesticCup,
    ),
    TeamTrophy(
      id: 'alpha-league-23-24',
      teamId: 1,
      seasonLabel: '23/24',
      name: 'League',
      competitionCode: 'LEAGUE',
      type: TeamTrophyType.domesticLeague,
    ),
    TeamTrophy(
      id: 'beta-league-24-25',
      teamId: 2,
      seasonLabel: '24/25',
      name: 'League',
      competitionCode: 'LEAGUE',
      type: TeamTrophyType.domesticLeague,
    ),
  ];

  test('returns only trophies for the requested team and season', () {
    final repository = createRepository(trophies);

    expect(
      repository.forTeamSeason(1, '24/25').map((trophy) => trophy.id),
      ['alpha-league-24-25', 'alpha-cup-24-25'],
    );
  });

  test('returns an empty list for an unknown team-season', () {
    final repository = createRepository(trophies);

    expect(repository.forTeamSeason(99, '24/25'), isEmpty);
    expect(repository.forTeamSeason(1, '25/26'), isEmpty);
  });

  test('does not expose a mutable result list', () {
    final repository = createRepository(trophies);
    final result = repository.forTeamSeason(1, '24/25');

    expect(() => result.clear(), throwsUnsupportedError);
  });
}
