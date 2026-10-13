import 'package:onetouch/core/api_json.dart' as api_json;

class ApiTeamProbabilityCardResponse {
  const ApiTeamProbabilityCardResponse({
    required this.event,
    required this.competitionId,
    required this.category,
    required this.probability,
    required this.changePp,
    required this.entropy,
    this.resolution = 'unresolved',
  });

  final String event;
  final int competitionId;
  final String category;
  final double probability;
  final double? changePp;
  final double? entropy;
  final String resolution;

  factory ApiTeamProbabilityCardResponse.fromJson(Map<String, dynamic> json) {
    final probability = api_json.requiredDouble(json, 'probability');
    if (probability < 0 || probability > 1) {
      throw const FormatException(
        'Expected "probability" to be between 0 and 1.',
      );
    }
    return ApiTeamProbabilityCardResponse(
      event: api_json.requiredString(json, 'event'),
      competitionId: api_json.requiredInt(json, 'competition_id'),
      category: api_json.requiredString(json, 'category'),
      probability: probability,
      changePp: _requiredNullableDouble(json, 'change_pp'),
      entropy: _requiredNullableDouble(json, 'entropy'),
      resolution: json.containsKey('resolution')
          ? api_json.requiredString(json, 'resolution')
          : 'unresolved',
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
      available: api_json.requiredBool(json, 'available'),
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
    final probability = api_json.requiredDouble(json, 'probability');
    if (probability < 0 || probability > 1) {
      throw const FormatException(
        'Expected position "probability" to be between 0 and 1.',
      );
    }
    return ApiTeamPositionProbabilityResponse(
      position: api_json.requiredInt(json, 'position'),
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
      lower: api_json.requiredInt(json, 'lower'),
      upper: api_json.requiredInt(json, 'upper'),
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
      mean: api_json.requiredDouble(json, 'mean'),
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
      asOf: api_json.requiredString(json, 'as_of'),
      played: api_json.requiredInt(json, 'played'),
      events: _requiredObjectList(json, 'events')
          .map(ApiTeamProbabilityCardResponse.fromJson)
          .toList(growable: false),
      expectedPoints: api_json.requiredDouble(json, 'expected_points'),
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
      fixtureId: api_json.requiredInt(json, 'fixture_id'),
      homeTeamId: api_json.requiredInt(json, 'home_team_id'),
      awayTeamId: api_json.requiredInt(json, 'away_team_id'),
      startingAt: api_json.requiredString(json, 'starting_at'),
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
    final outcome = api_json.requiredString(json, 'outcome');
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

class ApiEuropeanStageHistoryPointResponse {
  const ApiEuropeanStageHistoryPointResponse({
    required this.stageKey,
    required this.probability,
  });

  final String stageKey;
  final double probability;

  factory ApiEuropeanStageHistoryPointResponse.fromJson(
      Map<String, dynamic> json) {
    return ApiEuropeanStageHistoryPointResponse(
      stageKey: api_json.requiredString(json, 'stage_key'),
      probability: _requiredProbability(json),
    );
  }
}

class ApiEuropeanStageProbabilityResponse {
  const ApiEuropeanStageProbabilityResponse({
    required this.stageKey,
    required this.probability,
    required this.resolution,
  });

  final String stageKey;
  final double probability;
  final String resolution;

  factory ApiEuropeanStageProbabilityResponse.fromJson(
      Map<String, dynamic> json) {
    return ApiEuropeanStageProbabilityResponse(
      stageKey: api_json.requiredString(json, 'stage_key'),
      probability: _requiredProbability(json),
      resolution: api_json.requiredString(json, 'resolution'),
    );
  }
}

class ApiTitleContenderResponse {
  const ApiTitleContenderResponse({
    required this.teamId,
    required this.teamName,
    required this.rank,
    required this.probability,
  });

  final int teamId;
  final String teamName;
  final int rank;
  final double probability;

  factory ApiTitleContenderResponse.fromJson(Map<String, dynamic> json) {
    return ApiTitleContenderResponse(
      teamId: api_json.requiredInt(json, 'team_id'),
      teamName: api_json.requiredString(json, 'team_name'),
      rank: api_json.requiredInt(json, 'rank'),
      probability: _requiredProbability(json),
    );
  }
}

class ApiTitleContendersResponse {
  ApiTitleContendersResponse({
    required this.rank,
    required this.rankChange,
    required List<ApiTitleContenderResponse> teams,
  }) : teams = List.unmodifiable(teams);

  final int rank;
  final int? rankChange;
  final List<ApiTitleContenderResponse> teams;

  factory ApiTitleContendersResponse.fromJson(Map<String, dynamic> json) {
    final change = json['rank_change'];
    if (change != null && change is! int) {
      throw const FormatException(
          'Expected nullable integer field "rank_change".');
    }
    return ApiTitleContendersResponse(
      rank: api_json.requiredInt(json, 'rank'),
      rankChange: change as int?,
      teams: _requiredObjectList(json, 'teams')
          .map(ApiTitleContenderResponse.fromJson)
          .toList(growable: false),
    );
  }
}

class ApiEuropeanWhatIfScenarioResponse {
  const ApiEuropeanWhatIfScenarioResponse({
    required this.outcome,
    required this.probability,
    required this.changePp,
  });

  final String outcome;
  final double? probability;
  final double? changePp;

  factory ApiEuropeanWhatIfScenarioResponse.fromJson(
      Map<String, dynamic> json) {
    final outcome = api_json.requiredString(json, 'outcome');
    if (!const {'win', 'draw', 'loss'}.contains(outcome)) {
      throw const FormatException('Expected a win, draw, or loss outcome.');
    }
    final probability = _requiredNullableDouble(json, 'probability');
    if (probability != null && (probability < 0 || probability > 1)) {
      throw const FormatException('Expected probability between 0 and 1.');
    }
    return ApiEuropeanWhatIfScenarioResponse(
      outcome: outcome,
      probability: probability,
      changePp: _requiredNullableDouble(json, 'change_pp'),
    );
  }
}

class ApiEuropeanWhatIfResponse {
  ApiEuropeanWhatIfResponse({
    required this.fixtureId,
    required List<ApiEuropeanWhatIfScenarioResponse> scenarios,
  }) : scenarios = List.unmodifiable(scenarios);

  final int fixtureId;
  final List<ApiEuropeanWhatIfScenarioResponse> scenarios;

  factory ApiEuropeanWhatIfResponse.fromJson(Map<String, dynamic> json) =>
      ApiEuropeanWhatIfResponse(
        fixtureId: api_json.requiredInt(
            _requiredObject(json, 'fixture'), 'fixture_id'),
        scenarios: _requiredObjectList(json, 'scenarios')
            .map(ApiEuropeanWhatIfScenarioResponse.fromJson)
            .toList(growable: false),
      );
}

class ApiEuropeanTitleResponse {
  ApiEuropeanTitleResponse({
    required List<ApiEuropeanStageHistoryPointResponse> history,
    required List<ApiEuropeanStageProbabilityResponse> stageProbabilities,
    required this.titleContenders,
    required this.whatIf,
  })  : history = List.unmodifiable(history),
        stageProbabilities = List.unmodifiable(stageProbabilities);

  final List<ApiEuropeanStageHistoryPointResponse> history;
  final List<ApiEuropeanStageProbabilityResponse> stageProbabilities;
  final ApiTitleContendersResponse titleContenders;
  final ApiEuropeanWhatIfResponse? whatIf;

  factory ApiEuropeanTitleResponse.fromJson(Map<String, dynamic> json) {
    return ApiEuropeanTitleResponse(
      history: _requiredObjectList(json, 'history')
          .map(ApiEuropeanStageHistoryPointResponse.fromJson)
          .toList(growable: false),
      stageProbabilities: _requiredObjectList(json, 'stage_probabilities')
          .map(ApiEuropeanStageProbabilityResponse.fromJson)
          .toList(growable: false),
      titleContenders: ApiTitleContendersResponse.fromJson(
          _requiredObject(json, 'title_contenders')),
      whatIf: _optionalObject(json, 'what_if') == null
          ? null
          : ApiEuropeanWhatIfResponse.fromJson(
              _optionalObject(json, 'what_if')!),
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
    required this.europeanTitle,
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
  final ApiEuropeanTitleResponse? europeanTitle;

  factory ApiTeamProbabilityResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamProbabilityResponse(
      teamId: api_json.requiredInt(json, 'team_id'),
      teamName: api_json.requiredString(json, 'team_name'),
      competitionId: api_json.requiredInt(json, 'competition_id'),
      seasonId: api_json.requiredInt(json, 'season_id'),
      seasonName: api_json.requiredString(json, 'season_name'),
      asOf: api_json.requiredString(json, 'as_of'),
      maximumPoints: api_json.requiredInt(json, 'maximum_points'),
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
      europeanTitle: _optionalObject(json, 'european_title') == null
          ? null
          : ApiEuropeanTitleResponse.fromJson(
              _optionalObject(json, 'european_title')!,
            ),
    );
  }
}

double _requiredProbability(Map<String, dynamic> json) {
  final value = api_json.requiredDouble(json, 'probability');
  if (value < 0 || value > 1) {
    throw const FormatException(
        'Expected "probability" to be between 0 and 1.');
  }
  return value;
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

double? _requiredNullableDouble(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable numeric field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected nullable numeric field "$key".');
}

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
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
