import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/models/home_data.dart';

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

  return HomeData(
    favoriteTeam: favoriteTeam,
    followingTeams: followingTeams,
    nextMatch: response.nextMatch == null
        ? null
        : fixtureFromApiResponse(response.nextMatch!),
    lastMatch: response.lastMatch == null
        ? null
        : fixtureFromApiResponse(response.lastMatch!),
    calendar:
        response.calendar.map(fixtureFromApiResponse).toList(growable: false),
  );
}
