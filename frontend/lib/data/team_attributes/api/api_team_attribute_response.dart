import 'package:onetouch/core/api_json.dart' as api_json;

/// Transport response for `GET /v1/teams/{team_id}/attributes`.
///
/// Supplying `season_id` returns the same shape for that historical season.
class ApiTeamAttributeResponse {
  const ApiTeamAttributeResponse({
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.isCurrent,
    required this.teamId,
    required this.teamName,
    required this.modelId,
    required this.possessionBuildUp,
    required this.attackingThreat,
    required this.chanceCreation,
    required this.finishing,
    required this.defending,
    required this.attributesUpdatedAt,
  });

  final int competitionId;
  final int seasonId;
  final String seasonName;
  final bool isCurrent;
  final int teamId;
  final String teamName;
  final int modelId;
  final double possessionBuildUp;
  final double attackingThreat;
  final double chanceCreation;
  final double finishing;
  final double defending;
  final String attributesUpdatedAt;

  factory ApiTeamAttributeResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamAttributeResponse(
      competitionId: api_json.requiredInt(json, 'competition_id'),
      seasonId: api_json.requiredInt(json, 'season_id'),
      seasonName: api_json.requiredString(json, 'season_name'),
      isCurrent: api_json.requiredBool(json, 'is_current'),
      teamId: api_json.requiredInt(json, 'team_id'),
      teamName: api_json.requiredString(json, 'team_name'),
      modelId: api_json.requiredInt(json, 'model_id'),
      possessionBuildUp: api_json.requiredDouble(json, 'possession_build_up'),
      attackingThreat: api_json.requiredDouble(json, 'attacking_threat'),
      chanceCreation: api_json.requiredDouble(json, 'chance_creation'),
      finishing: api_json.requiredDouble(json, 'finishing'),
      defending: api_json.requiredDouble(json, 'defending'),
      attributesUpdatedAt:
          api_json.requiredString(json, 'attributes_updated_at'),
    );
  }
}
