import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

Team fixtureHomeTeam(Fixture fixture, TeamRepository repository) {
  return _fixtureTeam(
    repository: repository,
    teamId: fixture.homeTeamId,
    apiName: fixture.homeTeamName,
    apiLogo: fixture.homeTeamLogo,
  );
}

Team fixtureAwayTeam(Fixture fixture, TeamRepository repository) {
  return _fixtureTeam(
    repository: repository,
    teamId: fixture.awayTeamId,
    apiName: fixture.awayTeamName,
    apiLogo: fixture.awayTeamLogo,
  );
}

Team _fixtureTeam({
  required TeamRepository repository,
  required int teamId,
  required String? apiName,
  required String? apiLogo,
}) {
  final repositoryTeam = repository.findById(teamId);
  final normalizedName = apiName?.trim();
  final normalizedLogo = apiLogo?.trim();

  return Team(
    teamId: teamId,
    name: normalizedName?.isNotEmpty ?? false
        ? normalizedName!
        : repositoryTeam?.name ?? 'Unknown Team',
    shortCode: repositoryTeam?.shortCode,
    imagePath: normalizedLogo?.isNotEmpty ?? false
        ? normalizedLogo
        : repositoryTeam?.imagePath,
    primaryColor: repositoryTeam?.primaryColor ?? 0xFFD82457,
  );
}
