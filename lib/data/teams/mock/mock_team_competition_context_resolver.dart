import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/standing.dart';

class MockTeamCompetitionContextResolver
    implements TeamCompetitionContextResolver {
  MockTeamCompetitionContextResolver({
    List<Competition>? competitions,
    List<Standing>? standings,
  }) : _contexts = _buildContexts(
          competitions ?? mockCompetitions,
          standings ?? mockStandings,
        );

  static const _domesticCompetitionIds = {8, 82, 301, 384, 564};

  final Map<int, TeamCompetitionContext> _contexts;

  @override
  TeamCompetitionContext? resolve(int teamId) => _contexts[teamId];

  static Map<int, TeamCompetitionContext> _buildContexts(
    List<Competition> competitions,
    List<Standing> standings,
  ) {
    final competitionsById = {
      for (final competition in competitions)
        competition.competitionId: competition,
    };
    final contexts = <int, TeamCompetitionContext>{};

    for (final standing in standings) {
      if (!_domesticCompetitionIds.contains(standing.competitionId) ||
          contexts.containsKey(standing.teamId)) {
        continue;
      }

      final competition = competitionsById[standing.competitionId];
      if (competition == null) continue;

      contexts[standing.teamId] = TeamCompetitionContext(
        teamId: standing.teamId,
        competitionId: competition.competitionId,
        competitionName: competition.name,
        currentPosition: standing.position,
      );
    }

    return Map.unmodifiable(contexts);
  }
}
