import 'package:onetouch/core/api_json.dart' as api_json;

class ApiMatchAnalysisResponse {
  const ApiMatchAnalysisResponse({
    required this.fixtureId,
    required this.available,
    required this.home,
    required this.away,
  });

  final int fixtureId;
  final bool available;
  final ApiMatchTeamAnalysisResponse? home;
  final ApiMatchTeamAnalysisResponse? away;

  factory ApiMatchAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final available = api_json.requiredBool(json, 'available');
    final teams = _nullableObject(json, 'teams');
    if (available && teams == null) {
      throw const FormatException(
        'Expected teams when match analysis is available.',
      );
    }
    if (!available && teams != null) {
      throw const FormatException(
        'Expected teams to be null when match analysis is unavailable.',
      );
    }
    return ApiMatchAnalysisResponse(
      fixtureId: api_json.requiredInt(json, 'fixture_id'),
      available: available,
      home: teams == null
          ? null
          : ApiMatchTeamAnalysisResponse.fromJson(
              _requiredObject(teams, 'home'),
            ),
      away: teams == null
          ? null
          : ApiMatchTeamAnalysisResponse.fromJson(
              _requiredObject(teams, 'away'),
            ),
    );
  }
}

class ApiMatchTeamAnalysisResponse {
  const ApiMatchTeamAnalysisResponse({
    required this.teamId,
    required this.keyPasses,
    required this.completedPassesIntoFinalThird,
    required this.completedPasses,
    required this.progressivePasses,
    required this.channels,
    required this.defensiveActivity,
  });

  final int teamId;
  final int keyPasses;
  final int completedPassesIntoFinalThird;
  final int completedPasses;
  final int progressivePasses;
  final ApiProgressionChannelsResponse channels;
  final ApiDefensiveActivityResponse defensiveActivity;

  factory ApiMatchTeamAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final attack = _requiredObject(json, 'attack');
    final progression = _requiredObject(json, 'progression');
    return ApiMatchTeamAnalysisResponse(
      teamId: api_json.requiredInt(json, 'team_id'),
      keyPasses: api_json.requiredInt(attack, 'key_passes'),
      completedPassesIntoFinalThird:
          api_json.requiredInt(attack, 'completed_passes_into_final_third'),
      completedPasses: api_json.requiredInt(progression, 'completed_passes'),
      progressivePasses:
          api_json.requiredInt(progression, 'progressive_passes'),
      channels: ApiProgressionChannelsResponse.fromJson(
        _requiredObjectList(progression, 'channels'),
      ),
      defensiveActivity: ApiDefensiveActivityResponse.fromJson(
        _requiredObject(json, 'defensive_activity'),
      ),
    );
  }
}

class ApiProgressionChannelResponse {
  const ApiProgressionChannelResponse({
    required this.count,
    required this.percentage,
  });

  final int count;
  final double? percentage;
}

class ApiProgressionChannelsResponse {
  const ApiProgressionChannelsResponse({
    required this.left,
    required this.center,
    required this.right,
  });

  final ApiProgressionChannelResponse left;
  final ApiProgressionChannelResponse center;
  final ApiProgressionChannelResponse right;

  factory ApiProgressionChannelsResponse.fromJson(
    List<Map<String, dynamic>> json,
  ) {
    ApiProgressionChannelResponse? left;
    ApiProgressionChannelResponse? center;
    ApiProgressionChannelResponse? right;

    for (final item in json) {
      final name = api_json.requiredString(item, 'channel');
      final channel = ApiProgressionChannelResponse(
        count: api_json.requiredInt(item, 'count'),
        percentage: _requiredNullableDouble(item, 'percentage'),
      );
      switch (name) {
        case 'left':
          if (left != null) {
            throw const FormatException(
                'Duplicate progression channel "left".');
          }
          left = channel;
        case 'center':
          if (center != null) {
            throw const FormatException(
              'Duplicate progression channel "center".',
            );
          }
          center = channel;
        case 'right':
          if (right != null) {
            throw const FormatException(
              'Duplicate progression channel "right".',
            );
          }
          right = channel;
        default:
          throw FormatException('Unknown progression channel "$name".');
      }
    }

    if (left == null || center == null || right == null) {
      throw const FormatException(
        'Expected left, center, and right progression channels.',
      );
    }

    return ApiProgressionChannelsResponse(
      left: left,
      center: center,
      right: right,
    );
  }
}

class ApiDefensiveActivityResponse {
  const ApiDefensiveActivityResponse({
    required this.complete,
    required this.missingPositionCount,
    required this.actionCount,
    required this.actions,
    required this.recoveries,
    required this.highRegains,
    required this.ownHalfPercentage,
    required this.opponentHalfPercentage,
    required this.averageRegainX,
    required this.averageRegainHeightMetres,
    required this.leagueComparisonDeltas,
  });

  final bool complete;
  final int missingPositionCount;
  final int actionCount;
  final List<ApiPitchPointResponse> actions;
  final int? recoveries;
  final int? highRegains;
  final double? ownHalfPercentage;
  final double? opponentHalfPercentage;
  final double? averageRegainX;
  final double? averageRegainHeightMetres;
  final List<double?> leagueComparisonDeltas;

  factory ApiDefensiveActivityResponse.fromJson(Map<String, dynamic> json) {
    final halves = _requiredObjectList(json, 'halves');
    Map<String, dynamic>? own;
    Map<String, dynamic>? opponent;
    for (final half in halves) {
      switch (api_json.requiredString(half, 'half')) {
        case 'own':
          own = half;
        case 'opponent':
          opponent = half;
        default:
          throw const FormatException('Unknown defensive half.');
      }
    }
    if (own == null || opponent == null) {
      throw const FormatException('Expected own and opponent regain halves.');
    }
    return ApiDefensiveActivityResponse(
      complete: api_json.requiredBool(json, 'complete'),
      missingPositionCount:
          api_json.requiredInt(json, 'missing_position_count'),
      actionCount: api_json.requiredInt(json, 'action_count'),
      actions: _requiredObjectList(json, 'actions')
          .map(
            (action) => ApiPitchPointResponse.fromJson(
              _requiredObject(action, 'attacking_position'),
            ),
          )
          .toList(growable: false),
      recoveries: _requiredNullableInt(json, 'recoveries'),
      highRegains: _requiredNullableInt(json, 'high_regains'),
      ownHalfPercentage: _requiredNullableDouble(own, 'percentage'),
      opponentHalfPercentage: _requiredNullableDouble(opponent, 'percentage'),
      averageRegainX: _requiredNullableDouble(json, 'average_regain_x'),
      averageRegainHeightMetres:
          _requiredNullableDouble(json, 'average_regain_height_m'),
      leagueComparisonDeltas: _requiredObjectList(json, 'league_comparison')
          .map((third) => _requiredNullableDouble(third, 'difference_pp'))
          .toList(growable: false),
    );
  }
}

class ApiMatchShotMapResponse {
  const ApiMatchShotMapResponse({
    required this.fixtureId,
    required this.available,
    required this.homeCount,
    required this.awayCount,
    required this.shots,
  });

  final int fixtureId;
  final bool available;
  final int? homeCount;
  final int? awayCount;
  final List<ApiMatchShotResponse> shots;

  factory ApiMatchShotMapResponse.fromJson(Map<String, dynamic> json) {
    final available = api_json.requiredBool(json, 'available');
    final counts = _nullableObject(json, 'counts');
    if (available && counts == null) {
      throw const FormatException(
        'Expected counts when the shot map is available.',
      );
    }
    return ApiMatchShotMapResponse(
      fixtureId: api_json.requiredInt(json, 'fixture_id'),
      available: available,
      homeCount: counts == null ? null : api_json.requiredInt(counts, 'home'),
      awayCount: counts == null ? null : api_json.requiredInt(counts, 'away'),
      shots: _requiredObjectList(json, 'shots')
          .map(ApiMatchShotResponse.fromJson)
          .toList(growable: false),
    );
  }
}

class ApiMatchShotResponse {
  const ApiMatchShotResponse({
    required this.eventId,
    required this.teamId,
    required this.playerId,
    required this.playerName,
    required this.minute,
    required this.extraMinute,
    required this.result,
    required this.start,
    required this.end,
  });

  final String eventId;
  final int teamId;
  final int? playerId;
  final String? playerName;
  final int minute;
  final int? extraMinute;
  final String result;
  final ApiPitchPointResponse start;
  final ApiPitchPointResponse end;

  factory ApiMatchShotResponse.fromJson(Map<String, dynamic> json) {
    return ApiMatchShotResponse(
      eventId: api_json.requiredString(json, 'external_event_id'),
      teamId: api_json.requiredInt(json, 'team_id'),
      playerId: _requiredNullableInt(json, 'player_id'),
      playerName: _requiredNullableString(json, 'player_name'),
      minute: api_json.requiredInt(json, 'minute'),
      extraMinute: _requiredNullableInt(json, 'extra_minute'),
      result: api_json.requiredString(json, 'result'),
      start: ApiPitchPointResponse.fromJson(_requiredObject(json, 'start')),
      end: ApiPitchPointResponse.fromJson(_requiredObject(json, 'end')),
    );
  }
}

class ApiPitchPointResponse {
  const ApiPitchPointResponse({required this.x, required this.y});

  final double x;
  final double y;

  factory ApiPitchPointResponse.fromJson(Map<String, dynamic> json) {
    final x = api_json.requiredDouble(json, 'x');
    final y = api_json.requiredDouble(json, 'y');
    if (x < 0 || x > 100 || y < 0 || y > 100) {
      throw const FormatException('Expected pitch coordinates from 0 to 100.');
    }
    return ApiPitchPointResponse(x: x, y: y);
  }
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Expected required object field "$key".');
}

Map<String, dynamic>? _nullableObject(
  Map<String, dynamic> json,
  String key,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable object field "$key".');
  }
  final value = json[key];
  if (value == null || value is Map<String, dynamic>) {
    return value as Map<String, dynamic>?;
  }
  throw FormatException('Expected nullable object field "$key".');
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

int? _requiredNullableInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
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
