import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/models/team.dart';

Team teamFromApiResponse(ApiTeamResponse response) {
  // TODO(teams-api): Map the backend-owned primary color once TeamOut exposes
  // it. Until then, API-loaded teams use Team's temporary domain fallback.
  return Team(
    teamId: response.teamId,
    name: response.name,
    shortCode: response.shortCode,
    imagePath: response.imagePath,
  );
}
