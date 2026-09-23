import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/mock/mock_team_competition_context_resolver.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/models/team_season_membership.dart';

void main() {
  final resolver = MockTeamCompetitionContextResolver();
  final current = mockSeasons
      .singleWhere((season) => season.competitionId == 8 && season.isCurrent);

  test('resolves domestic competition context separately from Team', () {
    final context = resolver.resolve(19);

    expect(context?.teamId, 19);
    expect(context?.seasonId, current.seasonId);
    expect(context?.competitionId, 8);
    expect(context?.competitionName, 'Premier League');
    // 현재 시즌의 순위가 없으면 지난 시즌 순위를 붙이지 않아요.
    expect(context?.currentPosition, isNull);
    expect(context?.label, 'Premier League');
  });

  test('returns null and an empty label for an unknown team', () {
    expect(resolver.resolve(-1), isNull);
    expect(resolver.labelFor(-1), isEmpty);
  });

  test('resolves current membership even when standing data is missing', () {
    final resolverWithoutStandings = MockTeamCompetitionContextResolver(
      standings: const [],
    );

    final context = resolverWithoutStandings.resolve(19);
    expect(context?.seasonId, current.seasonId);
    expect(context?.competitionId, 8);
    expect(context?.competitionName, 'Premier League');
    expect(context?.currentPosition, isNull);
    expect(context?.label, 'Premier League');
  });

  test('does not present a previous-season-only team as current', () {
    final historicalOnly =
        MockTeamCompetitionContextResolver(memberships: const [
      TeamSeasonMembership(teamId: 116, seasonId: 23614, competitionId: 8),
    ]);
    expect(historicalOnly.resolve(116), isNull);
    expect(historicalOnly.labelFor(116), isEmpty);
  });
}
