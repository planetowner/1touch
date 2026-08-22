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
}
