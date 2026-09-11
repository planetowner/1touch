import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';

HomeData homeDataFromApiResponse(ApiHomeResponse response) {
  final favoriteResponse = response.favoriteTeam;
  if (favoriteResponse == null) {
    throw StateError('Home response requires a favorite team.');
  }

  final favoriteTeam = teamFromApiResponse(favoriteResponse);
  final followingTeams =
      response.followingTeams.map(teamFromApiResponse).toList(growable: false);
  if (!followingTeams.any((team) => team.teamId == favoriteTeam.teamId)) {
    throw StateError(
      'Favorite team ${favoriteTeam.teamId} must belong to following teams.',
    );
  }

  final calendar = response.calendar.map((fixtureResponse) {
    final fixture = fixtureFromApiResponse(fixtureResponse);
    final favoriteIsHome = fixture.homeTeamId == favoriteTeam.teamId;
    final favoriteIsAway = fixture.awayTeamId == favoriteTeam.teamId;
    if (!favoriteIsHome && !favoriteIsAway) {
      throw StateError(
        'Home calendar fixture ${fixture.fixtureId} does not include favorite '
        'team ${favoriteTeam.teamId}.',
      );
    }

    return HomeCalendarFixture(
      fixture: fixture,
      opponent: Team(
        teamId: favoriteIsHome
            ? fixtureResponse.awayTeamId
            : fixtureResponse.homeTeamId,
        name: favoriteIsHome
            ? fixtureResponse.awayTeamName
            : fixtureResponse.homeTeamName,
        imagePath: favoriteIsHome
            ? fixtureResponse.awayTeamLogo
            : fixtureResponse.homeTeamLogo,
      ),
    );
  }).toList(growable: false);

  return HomeData(
    favoriteTeam: favoriteTeam,
    followingTeams: followingTeams,
    nextMatch: response.nextMatch == null
        ? null
        : fixtureFromApiResponse(response.nextMatch!),
    lastMatch: response.lastMatch == null
        ? null
        : fixtureFromApiResponse(response.lastMatch!),
    calendar: calendar,
  );
}
