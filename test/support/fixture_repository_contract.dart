import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/models/fixture.dart';

void fixtureRepositoryContract({
  required FixtureRepository Function(List<Fixture> fixtures) createRepository,
}) {
  const fixtures = <Fixture>[
    Fixture(
      fixtureId: 4,
      seasonId: 200,
      competitionId: 8,
      homeTeamId: 1,
      awayTeamId: 3,
      competitionType: CompetitionType.league,
      roundName: '4',
      status: FixtureStatus.upcoming,
      startingAt: '2026-04-20 15:00:00',
    ),
    Fixture(
      fixtureId: 2,
      seasonId: 100,
      competitionId: 24,
      homeTeamId: 2,
      awayTeamId: 1,
      competitionType: CompetitionType.cup,
      roundName: 'Final',
      status: FixtureStatus.past,
      startingAt: '2025-05-10 15:00:00',
      homeScore: 0,
      awayScore: 1,
    ),
    Fixture(
      fixtureId: 3,
      seasonId: 200,
      competitionId: 8,
      homeTeamId: 2,
      awayTeamId: 1,
      competitionType: CompetitionType.league,
      roundName: '3',
      status: FixtureStatus.upcoming,
      startingAt: '2026-03-20 15:00:00',
    ),
    Fixture(
      fixtureId: 1,
      seasonId: 100,
      competitionId: 8,
      homeTeamId: 1,
      awayTeamId: 2,
      competitionType: CompetitionType.league,
      roundName: '1',
      status: FixtureStatus.past,
      startingAt: '2025-01-10 15:00:00',
      homeScore: 2,
      awayScore: 1,
    ),
    Fixture(
      fixtureId: 5,
      seasonId: 100,
      competitionId: 8,
      homeTeamId: 2,
      awayTeamId: 1,
      competitionType: CompetitionType.league,
      roundName: '2',
      status: FixtureStatus.past,
      startingAt: '2025-03-10 15:00:00',
      homeScore: 1,
      awayScore: 1,
    ),
  ];

  late FixtureRepository repository;

  setUp(() => repository = createRepository(fixtures));

  test('indexes fixtures by ID and orders the catalog chronologically', () {
    expect(repository.findById(1), same(fixtures[3]));
    expect(repository.findById(-1), isNull);
    expect(repository.allFixtures.map((fixture) => fixture.fixtureId),
        [1, 5, 2, 3, 4]);
  });

  test('filters team fixtures by season, competition, and status', () {
    expect(
      repository.forTeam(1, seasonId: 100).map((fixture) => fixture.fixtureId),
      [1, 5, 2],
    );
    expect(
      repository
          .forTeam(1, competitionId: 8, status: FixtureStatus.past)
          .map((fixture) => fixture.fixtureId),
      [1, 5],
    );
    expect(repository.forTeam(-1), isEmpty);
  });

  test('selects deterministic next and last fixtures', () {
    expect(repository.nextForTeam(1)?.fixtureId, 3);
    expect(repository.nextForTeam(1, seasonId: 100), isNull);
    expect(repository.lastForTeam(1)?.fixtureId, 2);
    expect(repository.lastForTeam(1, competitionId: 8)?.fixtureId, 5);
  });

  test('returns past head-to-head fixtures newest first', () {
    expect(
      repository.headToHead(1, 2).map((fixture) => fixture.fixtureId),
      [2, 5, 1],
    );
    expect(
      repository
          .headToHead(2, 1, competitionId: 8)
          .map((fixture) => fixture.fixtureId),
      [5, 1],
    );
    expect(repository.headToHead(1, 3), isEmpty);
  });

  test('does not expose mutable fixture result lists', () {
    expect(
      () => repository.allFixtures.add(fixtures.first),
      throwsUnsupportedError,
    );
    expect(
      () => repository.forTeam(1).clear(),
      throwsUnsupportedError,
    );
    expect(
      () => repository.headToHead(1, 2).clear(),
      throwsUnsupportedError,
    );
  });

  test('keeps the listenable cache consistent after initialization', () async {
    await repository.initialize();

    expect(repository.fixtures.value, same(repository.allFixtures));
  });
}
