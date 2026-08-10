import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';

import 'support/team_repository_contract.dart';

void main() {
  group('MockTeamRepository contract', () {
    teamRepositoryContract(
      createRepository: MockTeamRepository.new,
      expectedTeamCount: mockTeams.length,
      knownTeamId: 19,
      knownTeamName: 'Arsenal',
      nameQuery: 'arsenal',
      shortCodeQuery: 'ars',
    );
  });
}
