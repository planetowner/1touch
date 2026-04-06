import 'team.dart';
import 'fixture.dart';

class HomeResponse {
  final TeamOut? favoriteTeam;
  final List<TeamOut> followingTeams;

  final FixtureOut? nextMatch;
  final FixtureOut? lastMatch;

  final List<FixtureOut> calendar;

  const HomeResponse({
    this.favoriteTeam,
    this.followingTeams = const [],
    this.nextMatch,
    this.lastMatch,
    this.calendar = const [],
  });
}