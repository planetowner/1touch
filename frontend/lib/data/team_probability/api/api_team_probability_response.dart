class ApiTeamProbabilityCardResponse {
  const ApiTeamProbabilityCardResponse({
    required this.event,
    required this.competitionId,
    required this.category,
    required this.probability,
    required this.changePp,
    required this.entropy,
  });

  final String event;
  final int competitionId;
  final String category;
  final double probability;
  final double? changePp;
  final double? entropy;

  factory ApiTeamProbabilityCardResponse.fromJson(Map<String, dynamic> json) {
    final probability = _requiredDouble(json, 'probability');
    if (probability < 0 || probability > 1) {
      throw const FormatException(
        'Expected "probability" to be between 0 and 1.',
      );
    }
    return ApiTeamProbabilityCardResponse(
      event: _requiredString(json, 'event'),
      competitionId: _requiredInt(json, 'competition_id'),
      category: _requiredString(json, 'category'),
      probability: probability,
      changePp: _requiredNullableDouble(json, 'change_pp'),
      entropy: _requiredNullableDouble(json, 'entropy'),
    );
  }
}

class ApiTeamProbabilityComparisonResponse {
  const ApiTeamProbabilityComparisonResponse({
    required this.available,
    required this.asOf,
  });

  final bool available;
  final String? asOf;

  factory ApiTeamProbabilityComparisonResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiTeamProbabilityComparisonResponse(
      available: _requiredBool(json, 'available'),
      asOf: _requiredNullableString(json, 'as_of'),
    );
  }
}

class ApiTeamPositionProbabilityResponse {
  const ApiTeamPositionProbabilityResponse({
    required this.position,
    required this.probability,
  });

  final int position;
  final double probability;

  factory ApiTeamPositionProbabilityResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final probability = _requiredDouble(json, 'probability');
    if (probability < 0 || probability > 1) {
      throw const FormatException(
        'Expected position "probability" to be between 0 and 1.',
      );
    }
    return ApiTeamPositionProbabilityResponse(
      position: _requiredInt(json, 'position'),
      probability: probability,
    );
  }
}

class ApiTeamPointsIntervalResponse {
  const ApiTeamPointsIntervalResponse({
    required this.lower,
    required this.upper,
  });

  final int lower;
  final int upper;

  factory ApiTeamPointsIntervalResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamPointsIntervalResponse(
      lower: _requiredInt(json, 'lower'),
      upper: _requiredInt(json, 'upper'),
    );
  }
}

class ApiTeamProjectedPointsResponse {
  const ApiTeamProjectedPointsResponse({
    required this.mean,
    required this.likelyRange,
    required this.changePoints,
  });

  final double mean;
  final ApiTeamPointsIntervalResponse likelyRange;
  final double? changePoints;

  factory ApiTeamProjectedPointsResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamProjectedPointsResponse(
      mean: _requiredDouble(json, 'mean'),
      likelyRange: ApiTeamPointsIntervalResponse.fromJson(
        _requiredObject(json, 'likely_range'),
      ),
      changePoints: _requiredNullableDouble(json, 'change_points'),
    );
  }
}

class ApiTeamProbabilityHistoryPointResponse {
  ApiTeamProbabilityHistoryPointResponse({
    required this.asOf,
    required this.played,
    required List<ApiTeamProbabilityCardResponse> events,
    required this.expectedPoints,
  }) : events = List.unmodifiable(events);

  final String asOf;
  final int played;
  final List<ApiTeamProbabilityCardResponse> events;
  final double expectedPoints;

  factory ApiTeamProbabilityHistoryPointResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiTeamProbabilityHistoryPointResponse(
      asOf: _requiredString(json, 'as_of'),
      played: _requiredInt(json, 'played'),
      events: _requiredObjectList(json, 'events')
          .map(ApiTeamProbabilityCardResponse.fromJson)
          .toList(growable: false),
      expectedPoints: _requiredDouble(json, 'expected_points'),
    );
  }
}

class ApiTeamProbabilityWhatIfFixtureResponse {
  ApiTeamProbabilityWhatIfFixtureResponse({
    required this.fixtureId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.startingAt,
    required this.roundName,
    required List<double> probabilities,
  }) : probabilities = List.unmodifiable(probabilities);

  final int fixtureId;
  final int homeTeamId;
  final int awayTeamId;
  final String startingAt;
  final String? roundName;
  final List<double> probabilities;

  factory ApiTeamProbabilityWhatIfFixtureResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final probabilities = _requiredNumberList(json, 'probabilities');
    if (probabilities.length != 3 ||
        probabilities.any((value) => value < 0 || value > 1)) {
      throw const FormatException(
        'Expected three valid home/draw/away probabilities.',
      );
    }
    return ApiTeamProbabilityWhatIfFixtureResponse(
      fixtureId: _requiredInt(json, 'fixture_id'),
      homeTeamId: _requiredInt(json, 'home_team_id'),
      awayTeamId: _requiredInt(json, 'away_team_id'),
      startingAt: _requiredString(json, 'starting_at'),
      roundName: _requiredNullableString(json, 'round_name'),
      probabilities: probabilities,
    );
  }
}

class ApiTeamProbabilityWhatIfScenarioResponse {
  ApiTeamProbabilityWhatIfScenarioResponse({
    required this.outcome,
    required List<ApiTeamProbabilityCardResponse> events,
    required List<ApiTeamPositionProbabilityResponse> positions,
    required this.projectedPoints,
  })  : events = List.unmodifiable(events),
        positions = List.unmodifiable(positions);

  final String outcome;
  final List<ApiTeamProbabilityCardResponse> events;
  final List<ApiTeamPositionProbabilityResponse> positions;
  final ApiTeamProjectedPointsResponse projectedPoints;

  factory ApiTeamProbabilityWhatIfScenarioResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final outcome = _requiredString(json, 'outcome');
    if (!const {'win', 'draw', 'loss'}.contains(outcome)) {
      throw const FormatException('Expected a win, draw, or loss outcome.');
    }
    return ApiTeamProbabilityWhatIfScenarioResponse(
      outcome: outcome,
      events: _requiredObjectList(json, 'events')
          .map(ApiTeamProbabilityCardResponse.fromJson)
          .toList(growable: false),
      positions: _requiredObjectList(json, 'positions')
          .map(ApiTeamPositionProbabilityResponse.fromJson)
          .toList(growable: false),
      projectedPoints: ApiTeamProjectedPointsResponse.fromJson(
        _requiredObject(json, 'projected_points'),
      ),
    );
  }
}

class ApiTeamProbabilityWhatIfResponse {
  ApiTeamProbabilityWhatIfResponse({
    required this.fixture,
    required List<ApiTeamProbabilityWhatIfScenarioResponse> scenarios,
  }) : scenarios = List.unmodifiable(scenarios);

  final ApiTeamProbabilityWhatIfFixtureResponse fixture;
  final List<ApiTeamProbabilityWhatIfScenarioResponse> scenarios;

  factory ApiTeamProbabilityWhatIfResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiTeamProbabilityWhatIfResponse(
      fixture: ApiTeamProbabilityWhatIfFixtureResponse.fromJson(
        _requiredObject(json, 'fixture'),
      ),
      scenarios: _requiredObjectList(json, 'scenarios')
          .map(ApiTeamProbabilityWhatIfScenarioResponse.fromJson)
          .toList(growable: false),
    );
  }
}

class ApiTeamProbabilityResponse {
  ApiTeamProbabilityResponse({
    required this.teamId,
    required this.teamName,
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.asOf,
    required this.maximumPoints,
    required List<ApiTeamPositionProbabilityResponse> positions,
    required this.projectedPoints,
    required this.comparison,
    required List<ApiTeamProbabilityCardResponse> cards,
    required List<ApiTeamProbabilityHistoryPointResponse> history,
    required List<String> pendingOutcomes,
    required this.whatIf,
  })  : positions = List.unmodifiable(positions),
        cards = List.unmodifiable(cards),
        history = List.unmodifiable(history),
        pendingOutcomes = List.unmodifiable(pendingOutcomes);

  final int teamId;
  final String teamName;
  final int competitionId;
  final int seasonId;
  final String seasonName;
  final String asOf;
  final int maximumPoints;
  final List<ApiTeamPositionProbabilityResponse> positions;
  final ApiTeamProjectedPointsResponse projectedPoints;
  final ApiTeamProbabilityComparisonResponse comparison;
  final List<ApiTeamProbabilityCardResponse> cards;
  final List<ApiTeamProbabilityHistoryPointResponse> history;
  final List<String> pendingOutcomes;
  final ApiTeamProbabilityWhatIfResponse? whatIf;

  factory ApiTeamProbabilityResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamProbabilityResponse(
      teamId: _requiredInt(json, 'team_id'),
      teamName: _requiredString(json, 'team_name'),
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      seasonName: _requiredString(json, 'season_name'),
      asOf: _requiredString(json, 'as_of'),
      maximumPoints: _requiredInt(json, 'maximum_points'),
      positions: _requiredObjectList(json, 'positions')
          .map(ApiTeamPositionProbabilityResponse.fromJson)
          .toList(growable: false),
      projectedPoints: ApiTeamProjectedPointsResponse.fromJson(
        _requiredObject(json, 'projected_points'),
      ),
      comparison: ApiTeamProbabilityComparisonResponse.fromJson(
        _requiredObject(json, 'comparison'),
      ),
      cards: _requiredObjectList(json, 'cards')
          .map(ApiTeamProbabilityCardResponse.fromJson)
          .toList(growable: false),
      history: _requiredObjectList(json, 'history')
          .map(ApiTeamProbabilityHistoryPointResponse.fromJson)
          .toList(growable: false),
      pendingOutcomes: _requiredStringList(json, 'pending_outcomes'),
      whatIf: _optionalObject(json, 'what_if') == null
          ? null
          : ApiTeamProbabilityWhatIfResponse.fromJson(
              _optionalObject(json, 'what_if')!,
            ),
    );
  }
}

Map<String, dynamic>? _optionalObject(
  Map<String, dynamic> json,
  String key,
) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Expected nullable object field "$key".');
}

List<double> _requiredNumberList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required numeric list field "$key".');
  }
  return value.map((item) {
    if (item is num) return item.toDouble();
    throw FormatException('Expected required numeric list field "$key".');
  }).toList(growable: false);
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

double? _requiredNullableDouble(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable numeric field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected nullable numeric field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
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

List<Map<String, dynamic>> _requiredObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required object list field "$key".');
  }
  return value.map((item) {
    if (item is Map<String, dynamic>) return item;
    throw FormatException('Expected required object list field "$key".');
  }).toList(growable: false);
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required string list field "$key".');
  }
  return value.map((item) {
    if (item is String) return item;
    throw FormatException('Expected required string list field "$key".');
  }).toList(growable: false);
}
