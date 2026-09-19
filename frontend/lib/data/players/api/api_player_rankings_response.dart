class ApiPlayerRankingsResponse {
  ApiPlayerRankingsResponse({
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.method,
    required this.reference,
    required this.total,
    required this.limit,
    required this.offset,
    required List<ApiRankedPlayerResponse> items,
  }) : items = List.unmodifiable(items);

  final int competitionId;
  final int seasonId;
  final String seasonName;
  final String method;
  final ApiPlayerRatingReferenceResponse reference;
  final int total;
  final int limit;
  final int offset;
  final List<ApiRankedPlayerResponse> items;

  factory ApiPlayerRankingsResponse.fromJson(Map<String, dynamic> json) {
    return ApiPlayerRankingsResponse(
      competitionId: _requiredInt(json, 'competition_id'),
      seasonId: _requiredInt(json, 'season_id'),
      seasonName: _requiredString(json, 'season_name'),
      method: _requiredString(json, 'method'),
      reference: ApiPlayerRatingReferenceResponse.fromJson(
        _requiredObject(json, 'reference'),
      ),
      total: _requiredInt(json, 'total'),
      limit: _requiredInt(json, 'limit'),
      offset: _requiredInt(json, 'offset'),
      items: _requiredObjectList(
        json,
        'items',
        ApiRankedPlayerResponse.fromJson,
      ),
    );
  }
}

class ApiPlayerRatingReferenceResponse {
  const ApiPlayerRatingReferenceResponse({
    required this.startSeasonName,
    required this.endSeasonName,
    required this.minimumRatedMatches,
    required this.sampleCount,
    required this.frozenAt,
  });

  final String startSeasonName;
  final String endSeasonName;
  final int minimumRatedMatches;
  final int sampleCount;
  final String frozenAt;

  factory ApiPlayerRatingReferenceResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiPlayerRatingReferenceResponse(
      startSeasonName: _requiredString(json, 'start_season_name'),
      endSeasonName: _requiredString(json, 'end_season_name'),
      minimumRatedMatches: _requiredInt(json, 'minimum_rated_matches'),
      sampleCount: _requiredInt(json, 'sample_count'),
      frozenAt: _requiredString(json, 'frozen_at'),
    );
  }
}

class ApiRankedPlayerResponse {
  const ApiRankedPlayerResponse({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.ratedMatches,
    required this.averageRating,
    required this.percentileScore,
    required this.displayScore,
    required this.updatedAt,
  });

  final int rank;
  final int playerId;
  final String playerName;
  final String? playerImage;
  final int ratedMatches;
  final double averageRating;
  final double percentileScore;
  final double displayScore;
  final String updatedAt;

  factory ApiRankedPlayerResponse.fromJson(Map<String, dynamic> json) {
    return ApiRankedPlayerResponse(
      rank: _requiredInt(json, 'rank'),
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      playerImage: _requiredNullableString(json, 'player_image'),
      ratedMatches: _requiredInt(json, 'rated_matches'),
      averageRating: _requiredDouble(json, 'average_rating'),
      percentileScore: _requiredDouble(json, 'percentile_score'),
      displayScore: _requiredDouble(json, 'display_score'),
      updatedAt: _requiredString(json, 'updated_at'),
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
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return List.unmodifiable(value.map((item) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('Expected each "$key" item to be an object.');
    }
    return parse(item);
  }));
}
