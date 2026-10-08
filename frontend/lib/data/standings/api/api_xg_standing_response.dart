import 'package:onetouch/core/api_json.dart' as api_json;

class ApiCompetitionXgStandingsResponse {
  ApiCompetitionXgStandingsResponse({
    required this.competitionId,
    required this.seasonId,
    required this.provider,
    required this.xptsMethod,
    required List<ApiXgStandingRowResponse> rows,
  }) : rows = List.unmodifiable(rows);

  final int competitionId;
  final int seasonId;
  final String provider;
  final String xptsMethod;
  final List<ApiXgStandingRowResponse> rows;

  factory ApiCompetitionXgStandingsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRows = json['rows'];
    if (rawRows is! List) {
      throw const FormatException('Expected required list field "rows".');
    }
    return ApiCompetitionXgStandingsResponse(
      competitionId: api_json.requiredInt(json, 'competition_id'),
      seasonId: api_json.requiredInt(json, 'season_id'),
      provider: api_json.requiredString(json, 'provider'),
      xptsMethod: api_json.requiredString(json, 'xpts_method'),
      rows: rawRows.map((row) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected every "rows" entry to be a JSON object.',
          );
        }
        return ApiXgStandingRowResponse.fromJson(row);
      }).toList(growable: false),
    );
  }
}

class ApiXgStandingRowResponse {
  const ApiXgStandingRowResponse({
    required this.position,
    required this.teamId,
    required this.teamName,
    this.teamShortName,
    required this.teamLogo,
    required this.matchesPlayed,
    required this.xg,
    required this.xga,
    required this.xpts,
  });

  final int position;
  final int teamId;
  final String teamName;
  final String? teamShortName;
  final String? teamLogo;
  final int matchesPlayed;
  final double xg;
  final double xga;
  final double xpts;

  factory ApiXgStandingRowResponse.fromJson(Map<String, dynamic> json) {
    return ApiXgStandingRowResponse(
      position: api_json.requiredInt(json, 'position'),
      teamId: api_json.requiredInt(json, 'team_id'),
      teamName: api_json.requiredString(json, 'team_name'),
      teamShortName: json.containsKey('team_short_name')
          ? _nullableString(json, 'team_short_name')
          : null,
      teamLogo: _nullableString(json, 'team_logo'),
      matchesPlayed: api_json.requiredInt(json, 'matches_played'),
      xg: api_json.requiredDouble(json, 'xg'),
      xga: api_json.requiredDouble(json, 'xga'),
      xpts: api_json.requiredDouble(json, 'xpts'),
    );
  }
}

String? _nullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
