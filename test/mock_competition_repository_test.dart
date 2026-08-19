import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/mock_competition_repository.dart';

import 'support/competition_repository_contract.dart';

void main() {
  group('MockCompetitionRepository contract', () {
    competitionRepositoryContract(
      createRepository: (competitions, domesticCompetitionIds) =>
          MockCompetitionRepository(
        competitions: competitions,
        domesticCompetitionIds: domesticCompetitionIds,
      ),
    );
  });

  test('wraps the existing mock competition catalog', () {
    final repository = MockCompetitionRepository();

    expect(repository.allCompetitions, hasLength(mockCompetitions.length));
    expect(
      repository.allCompetitions
          .map((competition) => competition.competitionId)
          .toSet(),
      mockCompetitions.map((competition) => competition.competitionId).toSet(),
    );
    expect(
      repository.domesticCompetitions
          .map((competition) => competition.competitionId)
          .toSet(),
      leagueNames.keys.toSet(),
    );
  });
}
