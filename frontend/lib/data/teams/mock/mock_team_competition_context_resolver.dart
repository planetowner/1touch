import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/teams/mock/team_season_catalog.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/models/team_season_membership.dart';

class MockTeamCompetitionContextResolver
    implements TeamCompetitionContextResolver {
  MockTeamCompetitionContextResolver({
    List<Competition>? competitions,
    List<Season>? seasons,
    List<TeamSeasonMembership>? memberships,
    List<Standing>? standings,
  }) : _contexts = _buildContexts(
          competitions ?? mockCompetitions,
          seasons ?? mockSeasons,
          memberships ?? mockTeamSeasonMemberships,
          standings ?? mockStandings,
        );

  static const _domesticCompetitionIds = {8, 82, 301, 384, 564};

  final Map<int, TeamCompetitionContext> _contexts;

  @override
  TeamCompetitionContext? resolve(int teamId) => _contexts[teamId];

  static Map<int, TeamCompetitionContext> _buildContexts(
    List<Competition> competitions,
    List<Season> seasons,
    List<TeamSeasonMembership> memberships,
    List<Standing> standings,
  ) {
    final competitionsById = {
      for (final competition in competitions)
        competition.competitionId: competition,
    };
    final currentSeasonsById = {
      for (final season in seasons)
        if (season.isCurrent &&
            _domesticCompetitionIds.contains(season.competitionId))
          season.seasonId: season,
    };
    final positionsByMembership = <(int, int, int), int>{
      for (final standing in standings)
        if (currentSeasonsById.containsKey(standing.seasonId))
          (
            standing.teamId,
            standing.seasonId,
            standing.competitionId,
          ): standing.position,
    };
    final contexts = <int, TeamCompetitionContext>{};

    for (final membership in memberships) {
      final season = currentSeasonsById[membership.seasonId];
      if (season == null || season.competitionId != membership.competitionId) {
        continue;
      }

      final competition = competitionsById[membership.competitionId];
      if (competition == null) continue;

      contexts[membership.teamId] = TeamCompetitionContext(
        teamId: membership.teamId,
        seasonId: membership.seasonId,
        competitionId: competition.competitionId,
        competitionName: competition.name,
        currentPosition: positionsByMembership[(
          membership.teamId,
          membership.seasonId,
          membership.competitionId,
        )],
      );
    }

    return Map.unmodifiable(contexts);
  }
}
