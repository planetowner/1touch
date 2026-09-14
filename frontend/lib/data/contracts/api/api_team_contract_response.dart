/// Transport response for `GET /v1/teams/{team_id}/contracts`.
class ApiTeamContractsResponse {
  const ApiTeamContractsResponse({
    required this.teamId,
    required this.seasonId,
    required this.players,
  });

  final int teamId;
  final int seasonId;
  final List<ApiPlayerContractResponse> players;

  factory ApiTeamContractsResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamContractsResponse(
      teamId: _requiredInt(json, 'team_id'),
      seasonId: _requiredInt(json, 'season_id'),
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
    required this.jerseyNumber,
    required this.startDate,
    required this.endDate,
  });

  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? jerseyNumber;
  final String? startDate;
  final String? endDate;

  factory ApiPlayerContractResponse.fromJson(Map<String, dynamic> json) {
    return ApiPlayerContractResponse(
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      playerImage: _nullableString(json, 'player_image'),
      jerseyNumber: _nullableInt(json, 'jersey_number'),
      startDate: _nullableString(json, 'start_date'),
      endDate: _nullableString(json, 'end_date'),
    );
  }
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
