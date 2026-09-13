/// Transport responses for the Current Form endpoints.
///
/// These classes mirror the backend field names exactly. Domain naming such as
/// `leagueId` is handled by the mapper rather than at the HTTP boundary.
class ApiCurrentFormOptionsResponse {
  const ApiCurrentFormOptionsResponse({
    required this.items,
    required this.limit,
  });

  final List<ApiCurrentFormOptionResponse> items;
  final int limit;

  factory ApiCurrentFormOptionsResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentFormOptionsResponse(
      items: _requiredObjectList(
        json,
        'items',
        ApiCurrentFormOptionResponse.fromJson,
      ),
      limit: _requiredInt(json, 'limit'),
    );
  }
}

class ApiCurrentFormOptionResponse {
  const ApiCurrentFormOptionResponse({
    required this.teamId,
    required this.teamName,
    required this.teamShortCode,
    required this.teamLogo,
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.roundsAvailable,
    required this.latestRound,
  });

  final int teamId;
  final String? teamName;
  final String? teamShortCode;
  final String? teamLogo;
  final int competitionId;
  final int seasonId;
  final String seasonName;
  final int roundsAvailable;
  final int latestRound;

  factory ApiCurrentFormOptionResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentFormOptionResponse(
      teamId: _requiredInt(json, 'team_id'),
      teamName: _nullableString(json, 'team_name'),
      teamShortCode: _nullableString(json, 'team_short_code'),
      teamLogo: _nullableString(json, 'team_logo'),
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      seasonName: _requiredString(json, 'season_name'),
      roundsAvailable: _requiredInt(json, 'rounds_available'),
      latestRound: _requiredInt(json, 'latest_round'),
    );
  }
}

class ApiCurrentFormResponse {
  const ApiCurrentFormResponse({
    required this.current,
    required this.comparison,
    required this.maxRound,
    required this.maxPoints,
  });

  final ApiCurrentFormSeriesResponse current;
  final ApiCurrentFormSeriesResponse comparison;
  final int maxRound;
  final int maxPoints;

  factory ApiCurrentFormResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentFormResponse(
      current: ApiCurrentFormSeriesResponse.fromJson(
        _requiredObject(json, 'current'),
      ),
      comparison: ApiCurrentFormSeriesResponse.fromJson(
        _requiredObject(json, 'comparison'),
      ),
      maxRound: _requiredInt(json, 'max_round'),
      maxPoints: _requiredInt(json, 'max_points'),
    );
  }
}

class ApiCurrentFormSeriesResponse {
  const ApiCurrentFormSeriesResponse({
    required this.teamId,
    required this.teamName,
    required this.teamShortCode,
    required this.teamLogo,
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.isCurrent,
    required this.points,
  });

  final int teamId;
  final String? teamName;
  final String? teamShortCode;
  final String? teamLogo;
  final int competitionId;
  final int seasonId;
  final String seasonName;
  final bool isCurrent;
  final List<ApiCurrentFormPointResponse> points;

  factory ApiCurrentFormSeriesResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentFormSeriesResponse(
      teamId: _requiredInt(json, 'team_id'),
      teamName: _nullableString(json, 'team_name'),
      teamShortCode: _nullableString(json, 'team_short_code'),
      teamLogo: _nullableString(json, 'team_logo'),
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      seasonName: _requiredString(json, 'season_name'),
      isCurrent: _requiredBool(json, 'is_current'),
      points: _requiredObjectList(
        json,
        'points',
        ApiCurrentFormPointResponse.fromJson,
      ),
    );
  }
}

class ApiCurrentFormPointResponse {
  const ApiCurrentFormPointResponse({
    required this.roundNo,
    required this.matchDate,
    required this.cumulativePoints,
  });

  final int roundNo;
  final String? matchDate;
  final int cumulativePoints;

  factory ApiCurrentFormPointResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentFormPointResponse(
      roundNo: _requiredInt(json, 'round_no'),
      matchDate: _nullableString(json, 'match_date'),
      cumulativePoints: _requiredInt(json, 'cumulative_points'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
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

Map<String, dynamic> _requiredObject(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Expected required object field "$key".');
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
