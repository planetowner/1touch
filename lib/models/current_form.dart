import 'package:flutter/foundation.dart';

@immutable
class CurrentFormOptionsQuery {
  CurrentFormOptionsQuery({
    required this.teamId,
    String search = '',
    this.limit = 100,
  }) : search = search.trim().toLowerCase();

  final int teamId;
  final String search;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is CurrentFormOptionsQuery &&
        other.teamId == teamId &&
        other.search == search &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(teamId, search, limit);
}

@immutable
class CurrentFormComparisonQuery {
  const CurrentFormComparisonQuery({
    required this.teamId,
    this.seasonId,
    required this.compareTeamId,
    required this.compareSeasonId,
  });

  final int teamId;
  final int? seasonId;
  final int compareTeamId;
  final int compareSeasonId;

  @override
  bool operator ==(Object other) {
    return other is CurrentFormComparisonQuery &&
        other.teamId == teamId &&
        other.seasonId == seasonId &&
        other.compareTeamId == compareTeamId &&
        other.compareSeasonId == compareSeasonId;
  }

  @override
  int get hashCode => Object.hash(
        teamId,
        seasonId,
        compareTeamId,
        compareSeasonId,
      );
}

@immutable
class CurrentFormPoint {
  const CurrentFormPoint({
    required this.roundNo,
    this.matchDate,
    required this.cumulativePoints,
  });

  final int roundNo;
  final DateTime? matchDate;
  final int cumulativePoints;

  factory CurrentFormPoint.fromJson(Map<String, dynamic> json) {
    return CurrentFormPoint(
      roundNo: (json['round_no'] as num).toInt(),
      matchDate: _dateTimeOrNull(json['match_date']),
      cumulativePoints: (json['cumulative_points'] as num).toInt(),
    );
  }
}

@immutable
class CurrentFormSeries {
  CurrentFormSeries({
    required this.teamId,
    this.teamName,
    this.teamShortCode,
    this.teamLogo,
    required this.leagueId,
    required this.seasonId,
    required this.seasonName,
    this.seasonStart,
    this.seasonEnd,
    required this.isCurrent,
    required List<CurrentFormPoint> points,
  }) : points = List.unmodifiable(points);

  final int teamId;
  final String? teamName;
  final String? teamShortCode;
  final String? teamLogo;
  final int leagueId;
  final int seasonId;
  final String seasonName;
  final DateTime? seasonStart;
  final DateTime? seasonEnd;
  final bool isCurrent;
  final List<CurrentFormPoint> points;

  factory CurrentFormSeries.fromJson(Map<String, dynamic> json) {
    return CurrentFormSeries(
      teamId: (json['team_id'] as num).toInt(),
      teamName: json['team_name'] as String?,
      teamShortCode: json['team_short_code'] as String?,
      teamLogo: json['team_logo'] as String?,
      leagueId: (json['league_id'] as num).toInt(),
      seasonId: (json['season_id'] as num).toInt(),
      seasonName: json['season_name'] as String,
      seasonStart: _dateTimeOrNull(json['season_starting_at']),
      seasonEnd: _dateTimeOrNull(json['season_ending_at']),
      isCurrent: json['is_current'] as bool,
      points: (json['points'] as List<dynamic>? ?? const [])
          .map(
            (point) => CurrentFormPoint.fromJson(
              point as Map<String, dynamic>,
            ),
          )
          .toList()
        ..sort((a, b) => a.roundNo.compareTo(b.roundNo)),
    );
  }
}

@immutable
class CurrentFormComparison {
  const CurrentFormComparison({
    required this.current,
    required this.comparison,
    required this.maxRound,
    required this.maxPoints,
  });

  final CurrentFormSeries current;
  final CurrentFormSeries comparison;
  final int maxRound;
  final int maxPoints;

  factory CurrentFormComparison.fromJson(Map<String, dynamic> json) {
    return CurrentFormComparison(
      current: CurrentFormSeries.fromJson(
        json['current'] as Map<String, dynamic>,
      ),
      comparison: CurrentFormSeries.fromJson(
        json['comparison'] as Map<String, dynamic>,
      ),
      maxRound: (json['max_round'] as num).toInt(),
      maxPoints: (json['max_points'] as num).toInt(),
    );
  }
}

@immutable
class CurrentFormOption {
  const CurrentFormOption({
    required this.teamId,
    this.teamName,
    this.teamShortCode,
    this.teamLogo,
    required this.leagueId,
    required this.seasonId,
    required this.seasonName,
    this.seasonStart,
    this.seasonEnd,
    required this.roundsAvailable,
    required this.latestRound,
  });

  final int teamId;
  final String? teamName;
  final String? teamShortCode;
  final String? teamLogo;
  final int leagueId;
  final int seasonId;
  final String seasonName;
  final DateTime? seasonStart;
  final DateTime? seasonEnd;
  final int roundsAvailable;
  final int latestRound;

  factory CurrentFormOption.fromJson(Map<String, dynamic> json) {
    return CurrentFormOption(
      teamId: (json['team_id'] as num).toInt(),
      teamName: json['team_name'] as String?,
      teamShortCode: json['team_short_code'] as String?,
      teamLogo: json['team_logo'] as String?,
      leagueId: (json['league_id'] as num).toInt(),
      seasonId: (json['season_id'] as num).toInt(),
      seasonName: json['season_name'] as String,
      seasonStart: _dateTimeOrNull(json['season_starting_at']),
      seasonEnd: _dateTimeOrNull(json['season_ending_at']),
      roundsAvailable: (json['rounds_available'] as num).toInt(),
      latestRound: (json['latest_round'] as num).toInt(),
    );
  }
}

DateTime? _dateTimeOrNull(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
