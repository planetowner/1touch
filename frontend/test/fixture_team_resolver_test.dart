import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

void main() {
  final repository = MockTeamRepository(
    teams: const [
      Team(
        teamId: 9,
        name: 'Manchester City',
        shortCode: 'MCI',
        imagePath: 'mock-city.png',
        primaryColor: 0xFF6CABDD,
      ),
    ],
  );

  test('uses API identity for an opponent absent from the team repository', () {
    final fixture = _fixture(
      awayTeamName: 'Norwich City',
      awayTeamLogo: 'https://cdn.example/norwich.png',
    );

    final away = fixtureAwayTeam(fixture, repository);

    expect(away.teamId, 33);
    expect(away.name, 'Norwich City');
    expect(away.imagePath, 'https://cdn.example/norwich.png');
    expect(away.shortCode, isNull);
  });

  test('keeps repository metadata while preferring API name and logo', () {
    final fixture = _fixture(
      homeTeamName: 'Manchester City FC',
      homeTeamLogo: 'https://cdn.example/city.png',
    );

    final home = fixtureHomeTeam(fixture, repository);

    expect(home.name, 'Manchester City FC');
    expect(home.shortCode, 'MCI');
    expect(home.imagePath, 'https://cdn.example/city.png');
    expect(home.primaryColor, 0xFF6CABDD);
  });

  test('falls back to repository identity when legacy fixtures omit it', () {
    final home = fixtureHomeTeam(_fixture(), repository);

    expect(home.name, 'Manchester City');
    expect(home.imagePath, 'mock-city.png');
  });
}

Fixture _fixture({
  String? homeTeamName,
  String? awayTeamName,
  String? homeTeamLogo,
  String? awayTeamLogo,
}) {
  return Fixture(
    fixtureId: 1,
    seasonId: 1,
    competitionId: 24,
    homeTeamId: 9,
    awayTeamId: 33,
    homeTeamName: homeTeamName,
    awayTeamName: awayTeamName,
    homeTeamLogo: homeTeamLogo,
    awayTeamLogo: awayTeamLogo,
    competitionType: CompetitionType.cup,
    roundName: null,
    status: FixtureStatus.upcoming,
    startingAt: null,
  );
}
