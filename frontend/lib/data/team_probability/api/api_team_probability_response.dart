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

class ApiTeamProbabilityResponse {
  ApiTeamProbabilityResponse({
    required this.teamId,
    required this.teamName,
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.asOf,
    required this.comparison,
    required List<ApiTeamProbabilityCardResponse> cards,
    required List<String> pendingOutcomes,
  })  : cards = List.unmodifiable(cards),
        pendingOutcomes = List.unmodifiable(pendingOutcomes);

  final int teamId;
  final String teamName;
  final int competitionId;
  final int seasonId;
  final String seasonName;
  final String asOf;
  final ApiTeamProbabilityComparisonResponse comparison;
  final List<ApiTeamProbabilityCardResponse> cards;
  final List<String> pendingOutcomes;

  factory ApiTeamProbabilityResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamProbabilityResponse(
      teamId: _requiredInt(json, 'team_id'),
      teamName: _requiredString(json, 'team_name'),
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      seasonName: _requiredString(json, 'season_name'),
      asOf: _requiredString(json, 'as_of'),
      comparison: ApiTeamProbabilityComparisonResponse.fromJson(
        _requiredObject(json, 'comparison'),
      ),
      cards: _requiredObjectList(json, 'cards')
          .map(ApiTeamProbabilityCardResponse.fromJson)
          .toList(growable: false),
      pendingOutcomes: _requiredStringList(json, 'pending_outcomes'),
    );
  }
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
