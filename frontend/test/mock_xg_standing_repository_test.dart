import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/standings/mock/mock_xg_standing_repository.dart';

import 'support/xg_standing_repository_contract.dart';

void main() {
  group('MockXgStandingRepository contract', () {
    xgStandingRepositoryContract(
      createRepository: (standings) =>
          MockXgStandingRepository(standings: standings),
    );
  });

  test('wraps the existing mock xG standing catalog', () {
    final repository = MockXgStandingRepository();

    expect(repository.allXgStandings, hasLength(mockXgStandings.length));
    expect(
      repository.forCompetition(8).map((standing) => standing.teamId),
      mockXgStandings
          .where((standing) => standing.competitionId == 8)
          .map((standing) => standing.teamId),
    );
  });
}
