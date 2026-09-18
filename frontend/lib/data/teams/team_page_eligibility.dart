import 'package:onetouch/data/teams/team_competition_context.dart';

/// Product policy for full Team-page availability.
///
/// Team identities outside this scope remain available for fixture opponent
/// names and logos, but only current domestic Big Five members receive a full
/// Team page.
class TeamPageEligibility {
  const TeamPageEligibility(this._contextResolver);

  static const Set<int> domesticBigFiveCompetitionIds = {
    8,
    82,
    301,
    384,
    564,
  };

  final TeamCompetitionContextResolver _contextResolver;

  bool supports(int teamId) {
    final context = _contextResolver.resolve(teamId);
    return context?.seasonId != null &&
        domesticBigFiveCompetitionIds.contains(context?.competitionId);
  }
}
