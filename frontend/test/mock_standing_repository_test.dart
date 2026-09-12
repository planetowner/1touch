import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/models/standing.dart';

import 'support/standing_repository_contract.dart';

void main() {
  group('MockStandingRepository contract', () {
    standingRepositoryContract(
      createRepository: (standings) =>
          MockStandingRepository(standings: standings),
    );
  });

  test('wraps the existing mock standing catalog', () {
    final repository = MockStandingRepository();

    expect(repository.allStandings, hasLength(mockStandings.length));
    expect(
      repository.forCompetition(8).map((standing) => standing.teamId),
      mockStandings
          .where((standing) => standing.competitionId == 8)
          .map((standing) => standing.teamId),
    );
  });

  test('stores UEFA league-phase standings in their verified contexts', () {
    final repository = MockStandingRepository();

    final championsLeague = repository.forCompetition(
      2,
      seasonId: 25580,
      phase: StandingPhase.leaguePhase,
    );
    final europaLeague = repository.forCompetition(
      5,
      seasonId: 25582,
      phase: StandingPhase.leaguePhase,
    );

    expect(championsLeague, hasLength(12));
    expect(europaLeague, hasLength(12));
    expect(
      repository.forCompetition(2, phase: StandingPhase.league),
      isEmpty,
    );
    expect(
      repository.forCompetition(5, phase: StandingPhase.league),
      isEmpty,
    );
  });

  test('keeps mock standing totals, form, and supported tie ordering coherent',
      () {
    final repository = MockStandingRepository();

    for (final standing in repository.allStandings) {
      expect(
        standing.won + standing.draw + standing.lost,
        standing.matchesPlayed,
        reason: 'team ${standing.teamId} has inconsistent match totals',
      );
      expect(
        standing.won * 3 + standing.draw,
        standing.points,
        reason: 'team ${standing.teamId} has inconsistent points',
      );
      expect(
        standing.goalsFor - standing.goalsAgainst,
        standing.goalDiff,
        reason: 'team ${standing.teamId} has inconsistent goal difference',
      );
      expect(standing.last5Form, hasLength(5));
      if (standing.won == 0) {
        expect(standing.last5Form, isNot(contains('W')));
      }
      if (standing.draw == 0) {
        expect(standing.last5Form, isNot(contains('D')));
      }
      if (standing.lost == 0) {
        expect(standing.last5Form, isNot(contains('L')));
      }
    }

    for (final context in [(82, 25646), (2, 25580)]) {
      final standings = repository.forCompetition(
        context.$1,
        seasonId: context.$2,
      );
      final expected = [...standings]..sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          if (byPoints != 0) return byPoints;
          final byGoalDifference = b.goalDiff.compareTo(a.goalDiff);
          if (byGoalDifference != 0) return byGoalDifference;
          final byGoalsFor = b.goalsFor.compareTo(a.goalsFor);
          if (byGoalsFor != 0) return byGoalsFor;
          return a.teamId.compareTo(b.teamId);
        });

      expect(
        standings.map((standing) => standing.teamId),
        expected.map((standing) => standing.teamId),
        reason: 'competition ${context.$1} is ordered inconsistently',
      );
    }
  });
}
