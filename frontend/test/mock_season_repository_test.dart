import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/seasons/mock/mock_season_repository.dart';

import 'support/season_repository_contract.dart';

void main() {
  group('MockSeasonRepository contract', () {
    seasonRepositoryContract(
      createRepository: (seasons) => MockSeasonRepository(seasons: seasons),
    );
  });

  test('wraps the existing mock season catalog', () {
    final repository = MockSeasonRepository();

    expect(repository.allSeasons, hasLength(mockSeasons.length));
    expect(
      repository.allSeasons.map((season) => season.seasonId).toSet(),
      mockSeasons.map((season) => season.seasonId).toSet(),
    );
    expect(repository.currentForCompetition(8)?.seasonId, 25583);
    expect(repository.currentForCompetition(2)?.seasonId, 25580);
    expect(repository.currentForCompetition(5)?.seasonId, 25582);
    expect(repository.currentForCompetition(2286)?.seasonId, 25581);
    expect(
      repository.forCompetition(8).map((season) => season.seasonId),
      [25583, 23614],
    );
  });
}
