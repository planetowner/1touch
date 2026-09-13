import 'package:onetouch/data/team_attributes/api/api_team_attribute_options_response.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

List<TeamAttributeSeasonOption> teamAttributeOptionsFromApiResponse(
  ApiTeamAttributeOptionsResponse response,
) {
  return List.unmodifiable(
    response.items.map(
      (item) => TeamAttributeSeasonOption(
        competitionId: item.competitionId,
        seasonId: item.seasonId,
        seasonName: item.seasonName,
        isCurrent: item.isCurrent,
      ),
    ),
  );
}
