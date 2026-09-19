class ApiTeamHighlightsResponse {
  ApiTeamHighlightsResponse({
    required this.teamId,
    required this.viewerCountry,
    required this.updatedAt,
    required List<ApiHighlightResponse> items,
  }) : items = List.unmodifiable(items);

  final int teamId;
  final String viewerCountry;
  final String? updatedAt;
  final List<ApiHighlightResponse> items;

  factory ApiTeamHighlightsResponse.fromJson(Map<String, dynamic> json) {
    final viewerCountry = _requiredString(json, 'viewer_country');
    if (!_isUppercaseIsoCode(viewerCountry)) {
      throw const FormatException(
        'Expected "viewer_country" to be an uppercase ISO country code.',
      );
    }
    return ApiTeamHighlightsResponse(
      teamId: _requiredInt(json, 'team_id'),
      viewerCountry: viewerCountry,
      updatedAt: _nullableString(json, 'updated_at'),
      items: _objectList(json, 'items')
          .map(ApiHighlightResponse.fromJson)
          .toList(growable: false),
    );
  }
}

bool _isUppercaseIsoCode(String value) =>
    value.length == 2 &&
    value.codeUnits.every((codeUnit) => codeUnit >= 65 && codeUnit <= 90);

class ApiHighlightResponse {
  const ApiHighlightResponse({
    required this.videoId,
    required this.videoUrl,
    required this.title,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.durationSeconds,
    required this.channelId,
    required this.channelName,
    required this.sourceType,
    required this.isExtended,
    required this.embeddable,
    required this.match,
  });

  final String videoId;
  final String videoUrl;
  final String title;
  final String? thumbnailUrl;
  final String publishedAt;
  final int durationSeconds;
  final String channelId;
  final String channelName;
  final String sourceType;
  final bool isExtended;
  final bool embeddable;
  final ApiHighlightMatchResponse match;

  factory ApiHighlightResponse.fromJson(Map<String, dynamic> json) {
    final sourceType = _requiredString(json, 'source_type');
    if (!const {'club', 'competition'}.contains(sourceType)) {
      throw FormatException('Unknown highlight source_type "$sourceType".');
    }
    return ApiHighlightResponse(
      videoId: _requiredString(json, 'video_id'),
      videoUrl: _requiredString(json, 'video_url'),
      title: _requiredString(json, 'title'),
      thumbnailUrl: _nullableString(json, 'thumbnail_url'),
      publishedAt: _requiredString(json, 'published_at'),
      durationSeconds: _requiredInt(json, 'duration_seconds'),
      channelId: _requiredString(json, 'channel_id'),
      channelName: _requiredString(json, 'channel_name'),
      sourceType: sourceType,
      isExtended: _requiredBool(json, 'is_extended'),
      embeddable: _requiredBool(json, 'embeddable'),
      match: ApiHighlightMatchResponse.fromJson(
        _requiredObject(json, 'match'),
      ),
    );
  }
}

class ApiHighlightMatchResponse {
  const ApiHighlightMatchResponse({
    required this.matchKey,
    required this.fixtureId,
    required this.competitionKey,
    required this.competitionName,
    required this.seasonName,
    required this.startingAt,
    required this.home,
    required this.away,
    required this.recordSource,
    required this.recordUrl,
  });

  final String matchKey;
  final int? fixtureId;
  final String competitionKey;
  final String competitionName;
  final String seasonName;
  final String startingAt;
  final ApiHighlightTeamResponse home;
  final ApiHighlightTeamResponse away;
  final String recordSource;
  final String recordUrl;

  factory ApiHighlightMatchResponse.fromJson(Map<String, dynamic> json) {
    return ApiHighlightMatchResponse(
      matchKey: _requiredString(json, 'match_key'),
      fixtureId: _nullableInt(json, 'fixture_id'),
      competitionKey: _requiredString(json, 'competition_key'),
      competitionName: _requiredString(json, 'competition_name'),
      seasonName: _requiredString(json, 'season_name'),
      startingAt: _requiredString(json, 'starting_at'),
      home: ApiHighlightTeamResponse.fromJson(_requiredObject(json, 'home')),
      away: ApiHighlightTeamResponse.fromJson(_requiredObject(json, 'away')),
      recordSource: _requiredString(json, 'record_source'),
      recordUrl: _requiredString(json, 'record_url'),
    );
  }
}

class ApiHighlightTeamResponse {
  const ApiHighlightTeamResponse({required this.teamId, required this.name});

  final int? teamId;
  final String name;

  factory ApiHighlightTeamResponse.fromJson(Map<String, dynamic> json) {
    return ApiHighlightTeamResponse(
      teamId: _nullableInt(json, 'team_id'),
      name: _requiredString(json, 'name'),
    );
  }
}

Map<String, dynamic> _requiredObject(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Expected required object field "$key".');
}

List<Map<String, dynamic>> _objectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return value.map((item) {
    if (item is Map<String, dynamic>) return item;
    throw FormatException('Expected every "$key" entry to be an object.');
  }).toList(growable: false);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected required boolean field "$key".');
}
