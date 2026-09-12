import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_trophies/mock/mock_team_trophy_repository.dart';

import 'support/team_trophy_repository_contract.dart';

void main() {
  group('MockTeamTrophyRepository contract', () {
    teamTrophyRepositoryContract(
      createRepository: (trophies) =>
          MockTeamTrophyRepository(trophies: trophies),
    );
  });

  test('wraps the existing team trophy catalog by default', () {
    final repository = MockTeamTrophyRepository();

    expect(repository.forTeamSeason(83, '24/25'), hasLength(2));
  });
}
