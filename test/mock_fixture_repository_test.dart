import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/models/fixture.dart';

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

  test('uses verified 2025/26 season IDs for UEFA fixtures', () {
    final championsLeague = mockFixtures
        .where((fixture) => fixture.competitionId == 2)
        .toList(growable: false);
    final europaLeague = mockFixtures
        .where((fixture) => fixture.competitionId == 5)
        .toList(growable: false);

    expect(championsLeague, isNotEmpty);
    expect(europaLeague, isNotEmpty);
    expect(
      championsLeague.every(
        (fixture) =>
            fixture.seasonId == 25580 &&
            fixture.competitionType == CompetitionType.europe,
      ),
      isTrue,
    );
    expect(
      europaLeague.every(
        (fixture) =>
            fixture.seasonId == 25582 &&
            fixture.competitionType == CompetitionType.europe,
      ),
      isTrue,
    );
  });
}
