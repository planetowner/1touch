import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/teams/mock/team_season_catalog.dart';

void main() {
  const seasonCompetitions = <int, int>{
    23614: 8,
    23744: 82,
    23643: 301,
    23621: 564,
    23746: 384,
    25583: 8,
    25646: 82,
    25651: 301,
    25659: 564,
    25533: 384,
  };
  const expectedTeamCounts = <int, int>{
    23614: 20,
    23744: 18,
    23643: 18,
    23621: 20,
    23746: 20,
    25583: 20,
    25646: 18,
    25651: 18,
    25659: 20,
    25533: 20,
  };

  test('contains both complete Big Five seasons', () {
    expect(mockTeamSeasonMemberships, hasLength(192));

    for (final entry in expectedTeamCounts.entries) {
      final memberships = mockTeamMembershipsForSeason(entry.key);

      expect(memberships, hasLength(entry.value), reason: '${entry.key}');
      expect(
        memberships.map((membership) => membership.competitionId).toSet(),
        {seasonCompetitions[entry.key]},
        reason: '${entry.key}',
      );
    }
  });

  test('uses unique team-season keys', () {
    final keys = mockTeamSeasonMemberships
        .map((membership) => '${membership.teamId}:${membership.seasonId}')
        .toSet();

    expect(keys, hasLength(mockTeamSeasonMemberships.length));
  });

  test('references known teams and matching seasons', () {
    final teamIds = mockTeams.map((team) => team.teamId).toSet();
    final seasonsById = {
      for (final season in mockSeasons) season.seasonId: season,
    };

    expect(teamIds, hasLength(mockTeams.length));
    expect(mockTeams, hasLength(111));

    for (final membership in mockTeamSeasonMemberships) {
      expect(teamIds, contains(membership.teamId));
      expect(seasonsById, contains(membership.seasonId));
      expect(
        seasonsById[membership.seasonId]!.competitionId,
        membership.competitionId,
      );
    }
  });

  test('marks only 2025/26 domestic seasons as current', () {
    const currentSeasonIds = {25583, 25646, 25651, 25659, 25533};
    const previousSeasonIds = {23614, 23744, 23643, 23621, 23746};

    for (final seasonId in currentSeasonIds) {
      expect(mockSeasons.singleWhere((s) => s.seasonId == seasonId).isCurrent,
          isTrue);
    }
    for (final seasonId in previousSeasonIds) {
      expect(mockSeasons.singleWhere((s) => s.seasonId == seasonId).isCurrent,
          isFalse);
    }
  });

  test('captures promotion and relegation between seasons', () {
    const changes = <int, ({List<int> departed, List<int> joined})>{
      8: (departed: [116, 42, 65], joined: [71, 3, 27]),
      82: (departed: [999, 3611], joined: [3320, 2708]),
      301: (departed: [1028, 581, 108], joined: [4508, 9257, 3513]),
      564: (departed: [844, 361, 2921], joined: [3457, 1099, 93]),
      384: (departed: [397, 267, 1628], joined: [2714, 10722, 1072]),
    };
    const previousSeasonByCompetition = <int, int>{
      8: 23614,
      82: 23744,
      301: 23643,
      564: 23621,
      384: 23746,
    };
    const currentSeasonByCompetition = <int, int>{
      8: 25583,
      82: 25646,
      301: 25651,
      564: 25659,
      384: 25533,
    };

    for (final entry in changes.entries) {
      final previousIds = mockTeamMembershipsForSeason(
        previousSeasonByCompetition[entry.key]!,
      ).map((membership) => membership.teamId).toSet();
      final currentIds = mockTeamMembershipsForSeason(
        currentSeasonByCompetition[entry.key]!,
      ).map((membership) => membership.teamId).toSet();

      expect(previousIds.difference(currentIds), entry.value.departed);
      expect(currentIds.difference(previousIds), entry.value.joined);
    }
  });

  test('provides immutable season results and exact membership lookup', () {
    final premierLeague = mockTeamMembershipsForSeason(23614);

    expect(
        () => premierLeague.add(premierLeague.first), throwsUnsupportedError);
    expect(mockTeamMembership(116, 23614)?.competitionId, 8);
    expect(mockTeamMembership(116, 25583), isNull);
  });
}
