import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';

/// Transport model for `GET /v1/fixtures/{fixture_id}`.
///
/// The backend returns the regular fixture fields and contextual match-detail
/// collections in one JSON object. Keeping this response separate prevents
/// those screen-specific collections from expanding the stable Fixture model.
class ApiFixtureDetailResponse {
  ApiFixtureDetailResponse({
    required this.fixture,
    required this.venueName,
    required this.expectedGoals,
    required List<ApiFixturePlayerExpectedGoalResponse> playerExpectedGoals,
    required List<ApiFixtureShotResponse> shots,
    required List<ApiFixtureEventResponse> events,
    required List<ApiFixtureStatisticResponse> statistics,
    List<ApiFixturePlayerStatisticResponse> playerStatistics = const [],
    required List<ApiFixtureLineupResponse> lineups,
    required List<ApiFixtureFormationResponse> formations,
    required List<ApiFixtureCoachResponse> coaches,
    required List<ApiFixturePressureResponse> pressure,
  })  : playerExpectedGoals = List.unmodifiable(playerExpectedGoals),
        shots = List.unmodifiable(shots),
        events = List.unmodifiable(events),
        statistics = List.unmodifiable(statistics),
        playerStatistics = List.unmodifiable(playerStatistics),
        lineups = List.unmodifiable(lineups),
        formations = List.unmodifiable(formations),
        coaches = List.unmodifiable(coaches),
        pressure = List.unmodifiable(pressure);

  final ApiFixtureResponse fixture;
  final String? venueName;
  final ApiFixtureExpectedGoalsResponse? expectedGoals;
  final List<ApiFixturePlayerExpectedGoalResponse> playerExpectedGoals;
  final List<ApiFixtureShotResponse> shots;
  final List<ApiFixtureEventResponse> events;
  final List<ApiFixtureStatisticResponse> statistics;
  final List<ApiFixturePlayerStatisticResponse> playerStatistics;
  final List<ApiFixtureLineupResponse> lineups;
  final List<ApiFixtureFormationResponse> formations;
  final List<ApiFixtureCoachResponse> coaches;
  final List<ApiFixturePressureResponse> pressure;

  factory ApiFixtureDetailResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureDetailResponse(
      fixture: ApiFixtureResponse.fromJson(json),
      venueName: _optionalString(json, 'venue_name'),
      expectedGoals: _optionalObject(
        json,
        'expected_goals',
        ApiFixtureExpectedGoalsResponse.fromJson,
      ),
      playerExpectedGoals: _objectList(
        json,
        'player_expected_goals',
        ApiFixturePlayerExpectedGoalResponse.fromJson,
      ),
      shots: _objectList(
        json,
        'shots',
        ApiFixtureShotResponse.fromJson,
      ),
      events: _objectList(
        json,
        'events',
        ApiFixtureEventResponse.fromJson,
      ),
      statistics: _objectList(
        json,
        'statistics',
        ApiFixtureStatisticResponse.fromJson,
      ),
      playerStatistics: _objectList(
        json,
        'player_statistics',
        ApiFixturePlayerStatisticResponse.fromJson,
      ),
      lineups: _objectList(
        json,
        'lineups',
        ApiFixtureLineupResponse.fromJson,
      ),
      formations: _objectList(
        json,
        'formations',
        ApiFixtureFormationResponse.fromJson,
      ),
      coaches: _objectList(
        json,
        'coaches',
        ApiFixtureCoachResponse.fromJson,
      ),
      pressure: _objectList(
        json,
        'pressure',
        ApiFixturePressureResponse.fromJson,
      ),
    );
  }
}

class ApiFixtureExpectedGoalsResponse {
  const ApiFixtureExpectedGoalsResponse({
    required this.homeXg,
    required this.awayXg,
    required this.homeXga,
    required this.awayXga,
    required this.provider,
  });

  final double homeXg;
  final double awayXg;
  final double homeXga;
  final double awayXga;
  final String provider;

  factory ApiFixtureExpectedGoalsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiFixtureExpectedGoalsResponse(
      homeXg: _requiredDouble(json, 'home_xg'),
      awayXg: _requiredDouble(json, 'away_xg'),
      homeXga: _requiredDouble(json, 'home_xga'),
      awayXga: _requiredDouble(json, 'away_xga'),
      provider: _requiredString(json, 'provider'),
    );
  }
}

class ApiFixturePlayerExpectedGoalResponse {
  const ApiFixturePlayerExpectedGoalResponse({
    required this.playerId,
    required this.playerName,
    required this.xg,
  });

  final int playerId;
  final String playerName;
  final double xg;

  factory ApiFixturePlayerExpectedGoalResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiFixturePlayerExpectedGoalResponse(
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      xg: _requiredDouble(json, 'xg'),
    );
  }
}

class ApiFixtureShotResponse {
  const ApiFixtureShotResponse({
    required this.shotId,
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.minute,
    required this.x,
    required this.y,
    required this.xg,
    required this.result,
  });

  final int shotId;
  final int teamId;
  final int playerId;
  final String playerName;
  final int minute;
  final double x;
  final double y;
  final double xg;
  final String result;

  factory ApiFixtureShotResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureShotResponse(
      shotId: _requiredInt(json, 'shot_id'),
      teamId: _requiredInt(json, 'team_id'),
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      minute: _requiredInt(json, 'minute'),
      x: _requiredDouble(json, 'x'),
      y: _requiredDouble(json, 'y'),
      xg: _requiredDouble(json, 'xg'),
      result: _requiredString(json, 'result'),
    );
  }
}

class ApiFixtureEventResponse {
  const ApiFixtureEventResponse({
    required this.eventId,
    required this.teamId,
    required this.eventTypeId,
    required this.eventTypeCode,
    required this.eventTypeName,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.relatedPlayerId,
    required this.relatedPlayerName,
    required this.relatedPlayerImage,
    required this.minute,
    required this.extraMinute,
    required this.onBench,
  });

  final int eventId;
  final int teamId;
  final int eventTypeId;
  final String eventTypeCode;
  final String eventTypeName;
  final int? playerId;
  final String? playerName;
  final String? playerImage;
  final int? relatedPlayerId;
  final String? relatedPlayerName;
  final String? relatedPlayerImage;
  final int minute;
  final int? extraMinute;
  final bool? onBench;

  factory ApiFixtureEventResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureEventResponse(
      eventId: _requiredInt(json, 'event_id'),
      teamId: _requiredInt(json, 'team_id'),
      eventTypeId: _requiredInt(json, 'event_type_id'),
      eventTypeCode: _requiredString(json, 'event_type_code'),
      eventTypeName: _requiredString(json, 'event_type_name'),
      playerId: _optionalInt(json, 'player_id'),
      playerName: _optionalString(json, 'player_name'),
      playerImage: _optionalString(json, 'player_image'),
      relatedPlayerId: _optionalInt(json, 'related_player_id'),
      relatedPlayerName: _optionalString(json, 'related_player_name'),
      relatedPlayerImage: _optionalString(json, 'related_player_image'),
      minute: _requiredInt(json, 'minute'),
      extraMinute: _optionalInt(json, 'extra_minute'),
      onBench: _optionalBool(json, 'on_bench'),
    );
  }
}

class ApiFixtureStatisticResponse {
  const ApiFixtureStatisticResponse({
    required this.teamId,
    required this.statTypeId,
    required this.statCode,
    required this.statName,
    required this.value,
  });

  final int teamId;
  final int statTypeId;
  final String statCode;
  final String statName;
  final double? value;

  factory ApiFixtureStatisticResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureStatisticResponse(
      teamId: _requiredInt(json, 'team_id'),
      statTypeId: _requiredInt(json, 'stat_type_id'),
      statCode: _requiredString(json, 'stat_code'),
      statName: _requiredString(json, 'stat_name'),
      value: _optionalDouble(json, 'value'),
    );
  }
}

class ApiFixturePlayerStatisticResponse {
  ApiFixturePlayerStatisticResponse({
    required this.teamId,
    required this.playerId,
    required this.matchPositionId,
    required this.positionGroup,
    required this.minutesPlayed,
    required this.rating,
    required this.isManOfMatch,
    required List<ApiFixturePlayerStatCategoryResponse> categories,
  }) : categories = List.unmodifiable(categories);

  final int teamId;
  final int playerId;
  final int? matchPositionId;
  final String? positionGroup;
  final int? minutesPlayed;
  final double? rating;
  final bool? isManOfMatch;
  final List<ApiFixturePlayerStatCategoryResponse> categories;

  factory ApiFixturePlayerStatisticResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiFixturePlayerStatisticResponse(
      teamId: _requiredInt(json, 'team_id'),
      playerId: _requiredInt(json, 'player_id'),
      matchPositionId: _optionalInt(json, 'match_position_id'),
      positionGroup: _optionalString(json, 'position_group'),
      minutesPlayed: _optionalInt(json, 'minutes_played'),
      rating: _optionalDouble(json, 'rating'),
      isManOfMatch: _optionalBool(json, 'is_man_of_match'),
      categories: _objectList(
        json,
        'categories',
        ApiFixturePlayerStatCategoryResponse.fromJson,
      ),
    );
  }
}

class ApiFixturePlayerStatCategoryResponse {
  ApiFixturePlayerStatCategoryResponse({
    required this.code,
    required this.label,
    required List<ApiFixturePlayerStatMetricResponse> metrics,
  }) : metrics = List.unmodifiable(metrics);

  final String code;
  final String label;
  final List<ApiFixturePlayerStatMetricResponse> metrics;

  factory ApiFixturePlayerStatCategoryResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiFixturePlayerStatCategoryResponse(
      code: _requiredString(json, 'code'),
      label: _requiredString(json, 'label'),
      metrics: _objectList(
        json,
        'metrics',
        ApiFixturePlayerStatMetricResponse.fromJson,
      ),
    );
  }
}

class ApiFixturePlayerStatMetricResponse {
  ApiFixturePlayerStatMetricResponse({
    required this.code,
    required this.label,
    required this.kind,
    required this.source,
    required List<int> statTypeIds,
    required this.value,
    required this.numerator,
    required this.denominator,
  }) : statTypeIds = List.unmodifiable(statTypeIds);

  final String code;
  final String label;
  final String kind;
  final String source;
  final List<int> statTypeIds;
  final double? value;
  final double? numerator;
  final double? denominator;

  factory ApiFixturePlayerStatMetricResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiFixturePlayerStatMetricResponse(
      code: _requiredString(json, 'code'),
      label: _requiredString(json, 'label'),
      kind: _requiredString(json, 'kind'),
      source: _requiredString(json, 'source'),
      statTypeIds: _requiredIntList(json, 'stat_type_ids'),
      value: _optionalDouble(json, 'value'),
      numerator: _optionalDouble(json, 'numerator'),
      denominator: _optionalDouble(json, 'denominator'),
    );
  }
}

class ApiFixtureLineupResponse {
  const ApiFixtureLineupResponse({
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.positionId,
    required this.lineupTypeId,
    required this.formationField,
    required this.jerseyNumber,
    required this.minutesPlayed,
    required this.rating,
  });

  final int teamId;
  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? positionId;
  final int lineupTypeId;
  final String? formationField;
  final int? jerseyNumber;
  final int? minutesPlayed;
  final double? rating;

  factory ApiFixtureLineupResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureLineupResponse(
      teamId: _requiredInt(json, 'team_id'),
      playerId: _requiredInt(json, 'player_id'),
      playerName: _requiredString(json, 'player_name'),
      playerImage: _optionalString(json, 'player_image'),
      positionId: _optionalInt(json, 'position_id'),
      lineupTypeId: _requiredInt(json, 'lineup_type_id'),
      formationField: _optionalString(json, 'formation_field'),
      jerseyNumber: _optionalInt(json, 'jersey_number'),
      minutesPlayed: _optionalInt(json, 'minutes_played'),
      rating: _optionalDouble(json, 'rating'),
    );
  }
}

class ApiFixtureFormationResponse {
  const ApiFixtureFormationResponse({
    required this.teamId,
    required this.formation,
  });

  final int teamId;
  final String formation;

  factory ApiFixtureFormationResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureFormationResponse(
      teamId: _requiredInt(json, 'team_id'),
      formation: _requiredString(json, 'formation'),
    );
  }
}

class ApiFixtureCoachResponse {
  const ApiFixtureCoachResponse({
    required this.teamId,
    required this.coachId,
    required this.name,
  });

  final int teamId;
  final int coachId;
  final String name;

  factory ApiFixtureCoachResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixtureCoachResponse(
      teamId: _requiredInt(json, 'team_id'),
      coachId: _requiredInt(json, 'coach_id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class ApiFixturePressureResponse {
  const ApiFixturePressureResponse({
    required this.teamId,
    required this.minute,
    required this.pressure,
  });

  final int teamId;
  final int minute;
  final double pressure;

  factory ApiFixturePressureResponse.fromJson(Map<String, dynamic> json) {
    return ApiFixturePressureResponse(
      teamId: _requiredInt(json, 'team_id'),
      minute: _requiredInt(json, 'minute'),
      pressure: _requiredDouble(json, 'pressure'),
    );
  }
}

T? _optionalObject<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable object field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is Map<String, dynamic>) return parse(value);
  throw FormatException('Expected nullable object field "$key".');
}

List<T> _objectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return value.map((item) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('Expected every "$key" entry to be a JSON object.');
    }
    return parse(item);
  }).toList(growable: false);
}

List<int> _requiredIntList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! int)) {
    throw FormatException('Expected required integer list field "$key".');
  }
  return List<int>.unmodifiable(value.cast<int>());
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected nullable integer field "$key".');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Expected required numeric field "$key".');
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
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

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  if (value is int && value == 0) return false;
  if (value is int && value == 1) return true;
  throw FormatException('Expected nullable boolean field "$key".');
}
