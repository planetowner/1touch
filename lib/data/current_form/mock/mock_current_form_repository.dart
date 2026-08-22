import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/teams/mock/team_season_catalog.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_season_membership.dart';

class MockCurrentFormRepository implements CurrentFormRepository {
  MockCurrentFormRepository({
    List<Team>? teams,
    List<Season>? seasons,
    List<TeamSeasonMembership>? memberships,
  })  : _teamsById = Map.unmodifiable({
          for (final team in teams ?? mockTeams) team.teamId: team,
        }),
        _seasonsById = Map.unmodifiable({
          for (final season in seasons ?? mockSeasons) season.seasonId: season,
        }),
        _memberships = List.unmodifiable(
          memberships ?? mockTeamSeasonMemberships,
        );

  final Map<int, Team> _teamsById;
  final Map<int, Season> _seasonsById;
  final List<TeamSeasonMembership> _memberships;
  final ValueNotifier<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      _cachedOptions = ValueNotifier(const {});
  final ValueNotifier<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      _cachedComparisons = ValueNotifier(const {});

  @override
  ValueListenable<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      get cachedOptions => _cachedOptions;

  @override
  ValueListenable<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      get cachedComparisons => _cachedComparisons;

  @override
  List<CurrentFormOption>? cachedOptionsFor(
    int teamId, {
    String search = '',
    int limit = 100,
  }) {
    return _cachedOptions.value[CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      limit: limit,
    )];
  }

  @override
  CurrentFormComparison? cachedComparisonFor(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  }) {
    return _cachedComparisons.value[CurrentFormComparisonQuery(
      teamId: teamId,
      seasonId: seasonId,
      compareTeamId: compareTeamId,
      compareSeasonId: compareSeasonId,
    )];
  }

  @override
  Future<List<CurrentFormOption>> loadOptions(
    int teamId, {
    String search = '',
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }

    final query = CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      limit: limit,
    );
    final cached = _cachedOptions.value[query];
    if (cached != null) return cached;

    if (!_teamsById.containsKey(teamId)) return const [];

    final options = <CurrentFormOption>[];
    for (final membership in _memberships) {
      final team = _teamsById[membership.teamId];
      final season = _seasonsById[membership.seasonId];
      if (team == null ||
          season == null ||
          season.competitionId != membership.competitionId) {
        continue;
      }

      if (query.search.isNotEmpty && !_matches(team, query.search)) continue;

      options.add(
        CurrentFormOption(
          teamId: team.teamId,
          teamName: team.name,
          teamShortCode: team.shortCode,
          teamLogo: team.imagePath,
          leagueId: membership.competitionId,
          seasonId: season.seasonId,
          seasonName: season.name,
          seasonStart: DateTime.tryParse(season.startingAt),
          seasonEnd: DateTime.tryParse(season.endingAt),
          roundsAvailable: _mockRoundsAvailable,
          latestRound: _mockRoundsAvailable,
        ),
      );
    }

    options.sort((a, b) {
      final bySeason = b.seasonStart?.compareTo(
            a.seasonStart ?? DateTime.fromMillisecondsSinceEpoch(0),
          ) ??
          -1;
      if (bySeason != 0) return bySeason;
      return (a.teamName ?? '').compareTo(b.teamName ?? '');
    });

    final result = List<CurrentFormOption>.unmodifiable(
      options.take(limit),
    );
    _cachedOptions.value = Map.unmodifiable({
      ..._cachedOptions.value,
      query: result,
    });
    return result;
  }

  @override
  Future<CurrentFormComparison?> loadComparison(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  }) async {
    final query = CurrentFormComparisonQuery(
      teamId: teamId,
      seasonId: seasonId,
      compareTeamId: compareTeamId,
      compareSeasonId: compareSeasonId,
    );
    final cached = _cachedComparisons.value[query];
    if (cached != null) return cached;

    final currentMembership = _findCurrentMembership(teamId, seasonId);
    final comparisonMembership = _findMembership(
      compareTeamId,
      compareSeasonId,
    );
    if (currentMembership == null || comparisonMembership == null) return null;

    final current = _seriesFor(
      currentMembership,
      _points(_currentCurve),
    );
    final comparison = _seriesFor(
      comparisonMembership,
      _points(_comparisonCurve),
    );
    if (current == null || comparison == null) return null;

    final allPoints = [...current.points, ...comparison.points];
    final result = CurrentFormComparison(
      current: current,
      comparison: comparison,
      maxRound: allPoints.fold(0, (max, point) => math.max(max, point.roundNo)),
      maxPoints: allPoints.fold(
        0,
        (max, point) => math.max(max, point.cumulativePoints),
      ),
    );
    _cachedComparisons.value = Map.unmodifiable({
      ..._cachedComparisons.value,
      query: result,
    });
    return result;
  }

  TeamSeasonMembership? _findCurrentMembership(int teamId, int? seasonId) {
    if (seasonId != null) return _findMembership(teamId, seasonId);

    for (final membership in _memberships) {
      final season = _seasonsById[membership.seasonId];
      if (membership.teamId == teamId && season?.isCurrent == true) {
        return membership;
      }
    }
    return null;
  }

  TeamSeasonMembership? _findMembership(int teamId, int seasonId) {
    for (final membership in _memberships) {
      if (membership.teamId == teamId && membership.seasonId == seasonId) {
        return membership;
      }
    }
    return null;
  }

  CurrentFormSeries? _seriesFor(
    TeamSeasonMembership membership,
    List<CurrentFormPoint> points,
  ) {
    final team = _teamsById[membership.teamId];
    final season = _seasonsById[membership.seasonId];
    if (team == null ||
        season == null ||
        season.competitionId != membership.competitionId) {
      return null;
    }

    return CurrentFormSeries(
      teamId: team.teamId,
      teamName: team.name,
      teamShortCode: team.shortCode,
      teamLogo: team.imagePath,
      leagueId: membership.competitionId,
      seasonId: season.seasonId,
      seasonName: season.name,
      seasonStart: DateTime.tryParse(season.startingAt),
      seasonEnd: DateTime.tryParse(season.endingAt),
      isCurrent: season.isCurrent,
      points: points,
    );
  }

  static bool _matches(Team team, String search) {
    return team.name.toLowerCase().contains(search) ||
        (team.shortCode?.toLowerCase().contains(search) ?? false);
  }

  static List<CurrentFormPoint> _points(List<int> cumulativePoints) {
    return List.unmodifiable([
      const CurrentFormPoint(roundNo: 0, cumulativePoints: 0),
      for (var index = 0; index < cumulativePoints.length; index++)
        CurrentFormPoint(
          roundNo: index + 1,
          cumulativePoints: cumulativePoints[index],
        ),
    ]);
  }

  // These curves are illustrative until the API repository supplies real match
  // results. Team, competition, and season identifiers come from real catalogs.
  static const _mockRoundsAvailable = 16;
  static const _currentCurve = [
    0,
    0,
    3,
    6,
    6,
    9,
    12,
    12,
    15,
    15,
    18,
    21,
    21,
    21,
    24,
    27,
  ];
  static const _comparisonCurve = [
    0,
    3,
    3,
    6,
    9,
    9,
    12,
    12,
    15,
    15,
    15,
    18,
    21,
    24,
    27,
    27,
  ];
}
