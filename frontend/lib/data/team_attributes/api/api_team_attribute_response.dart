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
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      seasonName: _requiredString(json, 'season_name'),
      isCurrent: _requiredBool(json, 'is_current'),
      teamId: _requiredInt(json, 'team_id'),
      teamName: _requiredString(json, 'team_name'),
      modelId: _requiredInt(json, 'model_id'),
      possessionBuildUp: _requiredDouble(json, 'possession_build_up'),
      attackingThreat: _requiredDouble(json, 'attacking_threat'),
      chanceCreation: _requiredDouble(json, 'chance_creation'),
      finishing: _requiredDouble(json, 'finishing'),
      defending: _requiredDouble(json, 'defending'),
      attributesUpdatedAt: _requiredString(json, 'attributes_updated_at'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Expected required numeric field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected required boolean field "$key".');
}
