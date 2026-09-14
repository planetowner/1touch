import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_response.dart';
import 'package:onetouch/models/team_overview.dart';

TeamOverview teamOverviewFromApiResponse(ApiTeamOverviewResponse response) {
  final teamId = response.team.teamId;
  final standing = response.standing;
  if (standing != null && standing.teamId != teamId) {
    throw StateError(
      'Team overview standing ${standing.teamId} does not match team $teamId.',
    );
  }

  final nextMatch = response.nextMatch;
  if (nextMatch != null &&
      nextMatch.homeTeamId != teamId &&
      nextMatch.awayTeamId != teamId) {
    throw StateError(
      'Next fixture ${nextMatch.fixtureId} does not include team $teamId.',
    );
  }

  final lastMatch = response.lastMatch;
  if (lastMatch != null &&
      lastMatch.homeTeamId != teamId &&
      lastMatch.awayTeamId != teamId) {
    throw StateError(
      'Last fixture ${lastMatch.fixtureId} does not include team $teamId.',
    );
  }

  return TeamOverview(
    id: teamId,
    name: response.team.name,
    shortName: response.team.shortCode ?? '',
    imagePath: response.team.imagePath ?? '',
    standing: standing?.toDomainMap(),
    nextMatch: nextMatch == null ? null : fixtureFromApiResponse(nextMatch),
    lastMatch: lastMatch == null ? null : fixtureFromApiResponse(lastMatch),
  );
}
