import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

Team fixtureHomeTeam(Fixture fixture, TeamRepository repository) {
  return _fixtureTeam(
    repository: repository,
    teamId: fixture.homeTeamId,
    apiName: fixture.homeTeamName,
    apiShortName: fixture.homeTeamShortName,
    apiLogo: fixture.homeTeamLogo,
  );
}

Team fixtureAwayTeam(Fixture fixture, TeamRepository repository) {
  return _fixtureTeam(
    repository: repository,
    teamId: fixture.awayTeamId,
    apiName: fixture.awayTeamName,
    apiShortName: fixture.awayTeamShortName,
    apiLogo: fixture.awayTeamLogo,
  );
}

Team _fixtureTeam({
  required TeamRepository repository,
  required int teamId,
  required String? apiName,
  required String? apiShortName,
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
    // API가 짧은 이름을 비워 두면 로컬 목록의 이름으로 덮어쓰지 않아요.
    shortName: apiName != null ? apiShortName : repositoryTeam?.shortName,
    imagePath: normalizedLogo?.isNotEmpty ?? false
        ? normalizedLogo
        : repositoryTeam?.imagePath,
    primaryColor: repositoryTeam?.primaryColor ?? 0xFFD82457,
  );
}
