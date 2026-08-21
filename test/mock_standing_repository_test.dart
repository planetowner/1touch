import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';

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
}
