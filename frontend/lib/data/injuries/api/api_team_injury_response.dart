/// Transport response for `GET /v1/teams/{team_id}/injuries`.
class ApiTeamInjuriesResponse {
  const ApiTeamInjuriesResponse({
    required this.teamId,
    required this.seasonId,
    required this.players,
  });

  final int teamId;
  final int seasonId;
  final List<ApiInjuredPlayerResponse> players;

  factory ApiTeamInjuriesResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamInjuriesResponse(
      teamId: _requiredInt(json, 'team_id'),
      seasonId: _requiredInt(json, 'season_id'),
      players: _requiredObjectList(
        json,
        'players',
        ApiInjuredPlayerResponse.fromJson,
      ),
    );
  }
}

class ApiInjuredPlayerResponse {
  const ApiInjuredPlayerResponse({
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.jerseyNumber,
    required this.injuries,
  });

  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? jerseyNumber;
  final List<ApiInjuryResponse> injuries;

  factory ApiInjuredPlayerResponse.fromJson(Map<String, dynamic> json) {
    return ApiInjuredPlayerResponse(
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      playerImage: _nullableString(json, 'player_image'),
      jerseyNumber: _nullableInt(json, 'jersey_number'),
      injuries: _requiredObjectList(
        json,
        'injuries',
        ApiInjuryResponse.fromJson,
      ),
    );
  }
}

class ApiInjuryResponse {
  const ApiInjuryResponse({
    required this.sidelineId,
    required this.typeId,
    required this.typeName,
    required this.startDate,
    required this.endDate,
  });

  final int sidelineId;
  final int typeId;
  final String typeName;
  final String? startDate;
  final String? endDate;

  factory ApiInjuryResponse.fromJson(Map<String, dynamic> json) {
    return ApiInjuryResponse(
      sidelineId: _requiredInt(json, 'sideline_id'),
      typeId: _requiredInt(json, 'type_id'),
      typeName: _requiredString(json, 'type_name'),
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
