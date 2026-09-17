import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';

void main() {
  test('supports only teams in a current domestic Big Five season', () {
    final eligibility = TeamPageEligibility(
      _MapContextResolver({
        1: const TeamCompetitionContext(
          teamId: 1,
          seasonId: 25646,
          competitionId: 8,
          competitionName: 'Premier League',
        ),
        2: const TeamCompetitionContext(
          teamId: 2,
          seasonId: 25646,
          competitionId: 24,
          competitionName: 'FA Cup',
        ),
        3: const TeamCompetitionContext(
          teamId: 3,
          competitionId: 8,
          competitionName: 'Premier League',
        ),
      }),
    );

    expect(eligibility.supports(1), isTrue);
    expect(eligibility.supports(2), isFalse);
    expect(eligibility.supports(3), isFalse);
    expect(eligibility.supports(999999), isFalse);
  });
}

class _MapContextResolver implements TeamCompetitionContextResolver {
  const _MapContextResolver(this.contexts);

  final Map<int, TeamCompetitionContext> contexts;

  @override
  TeamCompetitionContext? resolve(int teamId) => contexts[teamId];
}
