import 'package:flutter/foundation.dart';

@immutable
class CurrentFormOptionsQuery {
  CurrentFormOptionsQuery({
    required this.teamId,
    String search = '',
    this.limit = 200,
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
}
