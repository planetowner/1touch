import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/home/mock/mock_home_repository.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

import 'support/home_repository_contract.dart';

void main() {
  final teamRepository = MockTeamRepository(
    teams: const [
      Team(teamId: 1, name: 'Alpha FC'),
      Team(teamId: 2, name: 'Beta FC'),
      Team(teamId: 3, name: 'Gamma FC'),
    ],
  );
  final fixtureRepository = MockFixtureRepository(
    fixtures: const [
      Fixture(
        fixtureId: 1,
        seasonId: 100,
        competitionId: 8,
        homeTeamId: 1,
        awayTeamId: 2,
        competitionType: CompetitionType.league,
        roundName: '1',
        status: FixtureStatus.past,
        startingAt: '2026-08-01 20:00:00',
      ),
      Fixture(
        fixtureId: 2,
        seasonId: 100,
        competitionId: 8,
        homeTeamId: 2,
        awayTeamId: 1,
        competitionType: CompetitionType.league,
        roundName: '2',
        status: FixtureStatus.live,
        startingAt: '2026-08-15 20:00:00',
      ),
      Fixture(
        fixtureId: 3,
        seasonId: 100,
        competitionId: 8,
        homeTeamId: 1,
        awayTeamId: 2,
        competitionType: CompetitionType.league,
        roundName: '3',
        status: FixtureStatus.upcoming,
        startingAt: '2026-08-31 20:00:00',
      ),
      Fixture(
        fixtureId: 4,
        seasonId: 100,
        competitionId: 8,
        homeTeamId: 2,
        awayTeamId: 3,
        competitionType: CompetitionType.league,
        roundName: '4',
        status: FixtureStatus.upcoming,
        startingAt: '2026-08-20 20:00:00',
      ),
    ],
  );

  group('MockHomeRepository contract', () {
    homeRepositoryContract(
      createRepository: () => MockHomeRepository(
        teamRepository: teamRepository,
        fixtureRepository: fixtureRepository,
        favoriteTeamId: () => 1,
        followedTeamIds: () => const [1, 2],
      ),
    );
  });

  test('reads the current user selection for every load', () async {
    var favoriteTeamId = 1;
    var followedTeamIds = <int>[1, 2];
    final repository = MockHomeRepository(
      teamRepository: teamRepository,
      fixtureRepository: fixtureRepository,
      favoriteTeamId: () => favoriteTeamId,
      followedTeamIds: () => followedTeamIds,
    );

    final first = await repository.load();
    favoriteTeamId = 2;
    followedTeamIds = [2, 3];
    final second = await repository.load();

    expect(first.favoriteTeam.teamId, 1);
    expect(second.favoriteTeam.teamId, 2);
    expect(second.followingTeams.map((team) => team.teamId), [2, 3]);
  });

  test('rejects a favorite outside the followed-team list', () async {
    final repository = MockHomeRepository(
      teamRepository: teamRepository,
      fixtureRepository: fixtureRepository,
      favoriteTeamId: () => 3,
      followedTeamIds: () => const [1, 2],
    );

    expect(
      repository.load(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      ),
      throwsStateError,
    );
  });
}
