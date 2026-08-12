import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';

import 'support/fixture_repository_contract.dart';

void main() {
  group('MockFixtureRepository contract', () {
    fixtureRepositoryContract(
      createRepository: (fixtures) => MockFixtureRepository(fixtures: fixtures),
    );
  });

  test('wraps the existing mock fixture catalog', () {
    final repository = MockFixtureRepository();

    expect(repository.allFixtures, hasLength(mockFixtures.length));
    expect(
      repository.allFixtures.map((fixture) => fixture.fixtureId).toSet(),
      mockFixtures.map((fixture) => fixture.fixtureId).toSet(),
    );
  });
}
