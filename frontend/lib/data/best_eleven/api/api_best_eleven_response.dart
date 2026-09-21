/// Transport response for `GET /v1/teams/{team_id}/best-eleven`.
class ApiBestElevenResponse {
  const ApiBestElevenResponse({
    required this.teamId,
    required this.seasonId,
    required this.formation,
    required this.matchesUsed,
    required this.totalValidMatches,
    required this.usagePercentage,
    required this.formations,
    required this.players,
  });

  final int teamId;
  final int seasonId;
  final String formation;
  final int matchesUsed;
  final int totalValidMatches;
  final double usagePercentage;
  final List<ApiBestElevenFormationResponse> formations;
  final List<ApiBestElevenPlayerResponse> players;

  factory ApiBestElevenResponse.fromJson(Map<String, dynamic> json) {
    return ApiBestElevenResponse(
      teamId: _requiredInt(json, 'team_id'),
      seasonId: _requiredInt(json, 'season_id'),
      formation: _requiredString(json, 'formation'),
      matchesUsed: _requiredInt(json, 'matches_used'),
      totalValidMatches: _requiredInt(json, 'total_valid_matches'),
      usagePercentage: _requiredDouble(json, 'usage_percentage'),
      formations: _requiredObjectList(
        json,
        'formations',
        ApiBestElevenFormationResponse.fromJson,
      ),
      players: _requiredObjectList(
        json,
        'players',
        ApiBestElevenPlayerResponse.fromJson,
      ),
    );
  }
}

class ApiBestElevenFormationResponse {
  const ApiBestElevenFormationResponse({
    required this.formation,
    required this.matchesUsed,
    required this.totalValidMatches,
    required this.usagePercentage,
    required this.isDefault,
  });

  final String formation;
  final int matchesUsed;
  final int totalValidMatches;
  final double usagePercentage;
  final bool isDefault;

  factory ApiBestElevenFormationResponse.fromJson(Map<String, dynamic> json) {
    return ApiBestElevenFormationResponse(
      formation: _requiredString(json, 'formation'),
      matchesUsed: _requiredInt(json, 'matches_used'),
      totalValidMatches: _requiredInt(json, 'total_valid_matches'),
      usagePercentage: _requiredDouble(json, 'usage_percentage'),
      isDefault: _requiredBool(json, 'is_default'),
    );
  }
}

class ApiBestElevenPlayerResponse {
  const ApiBestElevenPlayerResponse({
    required this.slotKey,
    required this.slotIndex,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.positionGroupCode,
    required this.positionCode,
    required this.starts,
    this.jerseyNumber,
  });

  final String slotKey;
  final int slotIndex;
  final int playerId;
  final String? playerName;
  final String? playerImage;
  final String? positionGroupCode;
  final String? positionCode;
  final int starts;
  final int? jerseyNumber;

  factory ApiBestElevenPlayerResponse.fromJson(Map<String, dynamic> json) {
    return ApiBestElevenPlayerResponse(
      slotKey: _requiredString(json, 'slot_key'),
      slotIndex: _requiredInt(json, 'slot_index'),
      playerId: _requiredInt(json, 'player_id'),
      playerName: _nullableString(json, 'player_name'),
      playerImage: _nullableString(json, 'player_image'),
      positionGroupCode: _nullableString(json, 'position_group_code'),
      positionCode: _nullableString(json, 'position_code'),
      starts: _requiredInt(json, 'starts'),
      jerseyNumber: _nullableInt(json, 'jersey_number'),
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

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected required boolean field "$key".');
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
