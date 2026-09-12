import 'package:onetouch/data/team_attributes/api/api_team_attribute_response.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

TeamAttributeScores teamAttributeScoresFromApiResponse(
  ApiTeamAttributeResponse response,
) {
  return TeamAttributeScores(
    teamId: response.teamId,
    seasonId: response.seasonId,
    seasonLabel: response.seasonName,
    attack: response.finishing,
    progression: response.attackingThreat,
    dominance: response.chanceCreation,
    defense: response.defending,
    possession: response.possessionBuildUp,
  );
}
