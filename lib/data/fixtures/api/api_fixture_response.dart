/// Transport model for the backend's current `FixtureOut` response.
///
/// This stays separate from the UI-facing [Fixture] domain model because the
/// two contracts currently differ in field names, nullability, and leg/state
/// representation.
class ApiFixtureResponse {
  const ApiFixtureResponse({
    required this.fixtureId,
    required this.competitionId,
    required this.seasonId,
    required this.competitionType,
    required this.roundName,
    required this.stageId,
    required this.stageName,
    required this.roundId,
    required this.groupId,
    required this.aggregateId,
    required this.leg,
    required this.venueId,
    required this.stateId,
    required this.stateCode,
    required this.stateName,
    required this.status,
    required this.startingAt,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
    required this.homePenaltyScore,
    required this.awayPenaltyScore,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamLogo,
    required this.awayTeamLogo,
  });

  final int fixtureId;
  final int competitionId;
  final int seasonId;
  final String competitionType;
  final String? roundName;
  final int stageId;
  final String stageName;
  final int? roundId;
  final int? groupId;
  final int? aggregateId;
  final String leg;
  final int? venueId;
  final int stateId;
  final String stateCode;
  final String stateName;
  final String? status;
  final String? startingAt;
  final int homeTeamId;
  final int awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final int? homePenaltyScore;
  final int? awayPenaltyScore;
  final String homeTeamName;
  final String awayTeamName;
  final String? homeTeamLogo;
  final String? awayTeamLogo;

  factory ApiFixtureResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureResponse(
      fixtureId: _requiredInt(json, 'fixture_id'),
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      competitionType: _requiredString(json, 'competition_type'),
      roundName: _optionalString(json, 'round_name'),
      stageId: _requiredInt(json, 'stage_id'),
      stageName: _requiredString(json, 'stage_name'),
      roundId: _optionalInt(json, 'round_id'),
      groupId: _optionalInt(json, 'group_id'),
      aggregateId: _optionalInt(json, 'aggregate_id'),
      leg: _requiredString(json, 'leg'),
      venueId: _optionalInt(json, 'venue_id'),
      stateId: _requiredInt(json, 'state_id'),
      stateCode: _requiredString(json, 'state_code'),
      stateName: _requiredString(json, 'state_name'),
      status: _optionalString(json, 'status'),
      startingAt: _optionalString(json, 'starting_at'),
      homeTeamId: _requiredInt(json, 'home_team_id'),
      awayTeamId: _requiredInt(json, 'away_team_id'),
      homeScore: _optionalInt(json, 'home_score'),
      awayScore: _optionalInt(json, 'away_score'),
      homePenaltyScore: _optionalInt(json, 'home_penalty_score'),
      awayPenaltyScore: _optionalInt(json, 'away_penalty_score'),
      homeTeamName: _requiredString(json, 'home_team_name'),
      awayTeamName: _requiredString(json, 'away_team_name'),
      homeTeamLogo: _optionalString(json, 'home_team_logo'),
      awayTeamLogo: _optionalString(json, 'away_team_logo'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected nullable integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
