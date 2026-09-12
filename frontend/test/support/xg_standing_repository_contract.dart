import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/standing.dart';

void xgStandingRepositoryContract({
  required XgStandingRepository Function(List<XgStanding> standings)
      createRepository,
}) {
  const standings = <XgStanding>[
    XgStanding(
      competitionId: 8,
      seasonId: 100,
      teamId: 1,
      position: 2,
      matchesPlayed: 10,
      won: 6,
      draw: 1,
      lost: 3,
      xg: 18.5,
      xga: 11.2,
      xpts: 19,
    ),
    XgStanding(
      competitionId: 8,
      seasonId: 100,
      teamId: 2,
      position: 1,
      matchesPlayed: 10,
      won: 7,
      draw: 1,
      lost: 2,
      xg: 22.4,
      xga: 9.7,
      xpts: 22,
    ),
    XgStanding(
      competitionId: 8,
      seasonId: 200,
      teamId: 3,
      position: 1,
      matchesPlayed: 1,
      won: 1,
      draw: 0,
      lost: 0,
      xg: 2.1,
      xga: 0.4,
      xpts: 3,
    ),
    XgStanding(
      competitionId: 82,
      seasonId: 100,
      teamId: 4,
      position: 1,
      matchesPlayed: 10,
      won: 8,
      draw: 0,
      lost: 2,
      xg: 24.8,
      xga: 10.1,
      xpts: 24,
    ),
  ];

  late XgStandingRepository repository;

  setUp(() => repository = createRepository(standings));

  test('preserves the xG standing catalog order', () {
    expect(repository.allXgStandings, orderedEquals(standings));
  });

  test('returns competition xG standings ordered by position', () {
    expect(
      repository
          .forCompetition(8, seasonId: 100)
          .map((standing) => standing.teamId),
      [2, 1],
    );
    expect(repository.forCompetition(-1), isEmpty);
  });

  test('filters xG standings by season', () {
    expect(
      repository
          .forCompetition(8, seasonId: 200)
          .map((standing) => standing.teamId),
      [3],
    );
  });

  test('finds a team only inside the requested xG context', () {
    expect(
      repository.findForTeam(8, 1, seasonId: 100),
      same(standings[0]),
    );
    expect(repository.findForTeam(8, 1, seasonId: 200), isNull);
    expect(repository.findForTeam(82, 1), isNull);
  });

  test('does not expose mutable xG standing lists', () {
    expect(
      () => repository.allXgStandings.add(standings.first),
      throwsUnsupportedError,
    );
    expect(
      () => repository.forCompetition(8).clear(),
      throwsUnsupportedError,
    );
  });

  test('keeps the listenable cache consistent after initialization', () async {
    await repository.initialize();

    expect(repository.xgStandings.value, same(repository.allXgStandings));
  });
}
