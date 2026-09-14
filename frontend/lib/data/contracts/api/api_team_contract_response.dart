/// Transport response for `GET /v1/teams/{team_id}/contracts`.
class ApiTeamContractsResponse {
  const ApiTeamContractsResponse({
    required this.teamId,
    required this.seasonId,
    required this.isCurrent,
    required this.players,
  });

  final int teamId;
  final int seasonId;
  final bool isCurrent;
  final List<ApiPlayerContractResponse> players;

  factory ApiTeamContractsResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamContractsResponse(
      teamId: _requiredInt(json, 'team_id'),
      seasonId: _requiredInt(json, 'season_id'),
      isCurrent: _requiredBool(json, 'is_current'),
      players: _requiredObjectList(
        json,
        'players',
        ApiPlayerContractResponse.fromJson,
      ),
    );
  }
}

class ApiPlayerContractResponse {
  const ApiPlayerContractResponse({
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.positionGroupId,
    required this.jerseyNumber,
    required this.dateOfBirth,
    required this.estimatedWeeklyGrossEur,
    required this.leadershipRole,
    required this.startDate,
    required this.endDate,
  });

  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? positionGroupId;
  final int? jerseyNumber;
  final String? dateOfBirth;
  final int? estimatedWeeklyGrossEur;
  final String? leadershipRole;
  final String? startDate;
  final String? endDate;

  factory ApiPlayerContractResponse.fromJson(Map<String, dynamic> json) {
    return ApiPlayerContractResponse(
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      playerImage: _nullableString(json, 'player_image'),
      positionGroupId: _nullableInt(json, 'position_group_id'),
      jerseyNumber: _nullableInt(json, 'jersey_number'),
      dateOfBirth: _nullableString(json, 'date_of_birth'),
      estimatedWeeklyGrossEur: _nullableInt(
        json,
        'estimated_weekly_gross_eur',
      ),
      leadershipRole: _nullableLeadershipRole(json, 'leadership_role'),
      startDate: _nullableString(json, 'start_date'),
      endDate: _nullableString(json, 'end_date'),
    );
  }
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected required boolean field "$key".');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}

String? _nullableLeadershipRole(Map<String, dynamic> json, String key) {
  final value = _nullableString(json, key);
  if (value == null || value == 'captain' || value == 'vice_captain') {
    return value;
  }
  throw FormatException('Unrecognized leadership role "$value".');
}

List<T> _requiredObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('Expected each "$key" item to be a JSON object.');
      }
      return fromJson(item);
    }),
  );
}
