class ApiCompetitionStandingsResponse {
  ApiCompetitionStandingsResponse({
    required this.competitionId,
    required this.seasonId,
    required List<ApiStandingRowResponse> rows,
  }) : rows = List.unmodifiable(rows);

  final int competitionId;
  final int seasonId;
  final List<ApiStandingRowResponse> rows;

  factory ApiCompetitionStandingsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRows = json['rows'];
    if (rawRows is! List) {
      throw const FormatException('Expected required list field "rows".');
    }
    return ApiCompetitionStandingsResponse(
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      rows: rawRows.map((row) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected every "rows" entry to be a JSON object.',
          );
        }
        return ApiStandingRowResponse.fromJson(row);
      }).toList(growable: false),
    );
  }
}

class ApiStandingRowResponse {
  ApiStandingRowResponse({
    required this.position,
    required this.rankDelta,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.matchesPlayed,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required List<String> lastFiveForm,
  }) : lastFiveForm = List.unmodifiable(lastFiveForm);

  final int position;
  final int? rankDelta;
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int matchesPlayed;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final List<String> lastFiveForm;

  factory ApiStandingRowResponse.fromJson(Map<String, dynamic> json) {
    final rawForm = json['last5_form'];
    if (rawForm is! List ||
        rawForm.length > 5 ||
        rawForm.any(
            (value) => value is! String || !{'W', 'D', 'L'}.contains(value))) {
      throw const FormatException(
        'Expected "last5_form" to contain at most five W/D/L strings.',
      );
    }

    return ApiStandingRowResponse(
      position: _requiredInt(json, 'position'),
      rankDelta: _optionalInt(json, 'rank_delta'),
      teamId: _requiredInt(json, 'team_id'),
      teamName: _requiredString(json, 'team_name'),
      teamLogo: _optionalString(json, 'team_logo'),
      matchesPlayed: _requiredInt(json, 'matches_played'),
      won: _requiredInt(json, 'won'),
      draw: _requiredInt(json, 'draw'),
      lost: _requiredInt(json, 'lost'),
      goalsFor: _requiredInt(json, 'goals_for'),
      goalsAgainst: _requiredInt(json, 'goals_against'),
      goalDiff: _requiredInt(json, 'goal_diff'),
      points: _requiredInt(json, 'points'),
      lastFiveForm: rawForm.cast<String>(),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
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
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
