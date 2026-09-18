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
    final available = _requiredBool(json, 'available');
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
      fixtureId: _requiredInt(json, 'fixture_id'),
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
  final List<ApiProgressionChannelResponse> channels;
  final ApiDefensiveActivityResponse defensiveActivity;

  factory ApiMatchTeamAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final attack = _requiredObject(json, 'attack');
    final progression = _requiredObject(json, 'progression');
    return ApiMatchTeamAnalysisResponse(
      teamId: _requiredInt(json, 'team_id'),
      keyPasses: _requiredInt(attack, 'key_passes'),
      completedPassesIntoFinalThird:
          _requiredInt(attack, 'completed_passes_into_final_third'),
      completedPasses: _requiredInt(progression, 'completed_passes'),
      progressivePasses: _requiredInt(progression, 'progressive_passes'),
      channels: _requiredObjectList(progression, 'channels')
          .map(ApiProgressionChannelResponse.fromJson)
          .toList(growable: false),
      defensiveActivity: ApiDefensiveActivityResponse.fromJson(
        _requiredObject(json, 'defensive_activity'),
      ),
    );
  }
}

class ApiProgressionChannelResponse {
  const ApiProgressionChannelResponse({
    required this.channel,
    required this.count,
    required this.percentage,
  });

  final String channel;
  final int count;
  final double? percentage;

  factory ApiProgressionChannelResponse.fromJson(Map<String, dynamic> json) {
    final channel = _requiredString(json, 'channel');
    if (!const {'left', 'center', 'right'}.contains(channel)) {
      throw FormatException('Unknown progression channel "$channel".');
    }
    return ApiProgressionChannelResponse(
      channel: channel,
      count: _requiredInt(json, 'count'),
      percentage: _requiredNullableDouble(json, 'percentage'),
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

  factory ApiDefensiveActivityResponse.fromJson(Map<String, dynamic> json) {
    final halves = _requiredObjectList(json, 'halves');
    Map<String, dynamic>? own;
    Map<String, dynamic>? opponent;
    for (final half in halves) {
      switch (_requiredString(half, 'half')) {
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
      complete: _requiredBool(json, 'complete'),
      missingPositionCount: _requiredInt(json, 'missing_position_count'),
      actionCount: _requiredInt(json, 'action_count'),
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
    final available = _requiredBool(json, 'available');
    final counts = _nullableObject(json, 'counts');
    if (available && counts == null) {
      throw const FormatException(
        'Expected counts when the shot map is available.',
      );
    }
    return ApiMatchShotMapResponse(
      fixtureId: _requiredInt(json, 'fixture_id'),
      available: available,
      homeCount: counts == null ? null : _requiredInt(counts, 'home'),
      awayCount: counts == null ? null : _requiredInt(counts, 'away'),
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
      eventId: _requiredString(json, 'external_event_id'),
      teamId: _requiredInt(json, 'team_id'),
      playerId: _requiredNullableInt(json, 'player_id'),
      playerName: _requiredNullableString(json, 'player_name'),
      minute: _requiredInt(json, 'minute'),
      extraMinute: _requiredNullableInt(json, 'extra_minute'),
      result: _requiredString(json, 'result'),
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
    final x = _requiredDouble(json, 'x');
    final y = _requiredDouble(json, 'y');
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

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _requiredNullableInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
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
