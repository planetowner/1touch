import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/standing.dart';

void standingRepositoryContract({
  required StandingRepository Function(List<Standing> standings)
      createRepository,
}) {
  const standings = <Standing>[
    Standing(
      competitionId: 8,
      seasonId: 100,
      phase: StandingPhase.league,
      groupName: '',
      teamId: 1,
      position: 2,
      matchesPlayed: 10,
      won: 6,
      draw: 2,
      lost: 2,
      goalsFor: 20,
      goalsAgainst: 10,
      goalDiff: 10,
      points: 20,
      last5Form: ['W', 'D', 'W', 'L', 'W'],
    ),
    Standing(
      competitionId: 8,
      seasonId: 100,
      phase: StandingPhase.league,
      groupName: '',
      teamId: 2,
      position: 1,
      matchesPlayed: 10,
      won: 7,
      draw: 2,
      lost: 1,
      goalsFor: 24,
      goalsAgainst: 8,
      goalDiff: 16,
      points: 23,
      last5Form: ['W', 'W', 'W', 'D', 'W'],
    ),
    Standing(
      competitionId: 8,
      seasonId: 200,
      phase: StandingPhase.league,
      groupName: '',
      teamId: 3,
      position: 1,
      matchesPlayed: 1,
      won: 1,
      draw: 0,
      lost: 0,
      goalsFor: 2,
      goalsAgainst: 0,
      goalDiff: 2,
      points: 3,
      last5Form: ['W'],
    ),
    Standing(
      competitionId: 2,
      seasonId: 100,
      phase: StandingPhase.leaguePhase,
      groupName: '',
      teamId: 1,
      position: 3,
      matchesPlayed: 8,
      won: 5,
      draw: 1,
      lost: 2,
      goalsFor: 16,
      goalsAgainst: 9,
      goalDiff: 7,
      points: 16,
      last5Form: ['W', 'L', 'W', 'W', 'D'],
    ),
    Standing(
      competitionId: 2,
      seasonId: 100,
      phase: StandingPhase.group,
      groupName: 'A',
      teamId: 4,
      position: 2,
      matchesPlayed: 6,
      won: 3,
      draw: 1,
      lost: 2,
      goalsFor: 9,
      goalsAgainst: 6,
      goalDiff: 3,
      points: 10,
      last5Form: ['W', 'D', 'L', 'W', 'W'],
    ),
    Standing(
      competitionId: 2,
      seasonId: 100,
      phase: StandingPhase.group,
      groupName: 'B',
      teamId: 5,
      position: 1,
      matchesPlayed: 6,
      won: 4,
      draw: 1,
      lost: 1,
      goalsFor: 12,
      goalsAgainst: 5,
      goalDiff: 7,
      points: 13,
      last5Form: ['W', 'W', 'L', 'W', 'D'],
    ),
  ];

  late StandingRepository repository;

  setUp(() => repository = createRepository(standings));

  test('preserves the standing catalog order', () {
    expect(repository.allStandings, orderedEquals(standings));
  });

  test('returns competition standings ordered by position', () {
    expect(
      repository
          .forCompetition(8, seasonId: 100)
          .map((standing) => standing.teamId),
      [2, 1],
    );
    expect(repository.forCompetition(-1), isEmpty);
  });

  test('filters standings by season, phase, and group', () {
    expect(
      repository
          .forCompetition(8, seasonId: 200)
          .map((standing) => standing.teamId),
      [3],
    );
    expect(
      repository
          .forCompetition(2, phase: StandingPhase.leaguePhase)
          .map((standing) => standing.teamId),
      [1],
    );
    expect(
      repository
          .forCompetition(
            2,
            phase: StandingPhase.group,
            groupName: 'A',
          )
          .map((standing) => standing.teamId),
      [4],
    );
  });

  test('finds a team only inside the requested standing context', () {
    expect(
      repository.findForTeam(8, 1, seasonId: 100),
      same(standings[0]),
    );
    expect(repository.findForTeam(8, 1, seasonId: 200), isNull);
    expect(
      repository.findForTeam(
        2,
        4,
        phase: StandingPhase.group,
        groupName: 'B',
      ),
      isNull,
    );
  });

  test('does not expose mutable standing lists', () {
    expect(
      () => repository.allStandings.add(standings.first),
      throwsUnsupportedError,
    );
    expect(
      () => repository.forCompetition(8).clear(),
      throwsUnsupportedError,
    );
  });

  test('keeps the listenable cache consistent after initialization', () async {
    await repository.initialize();

    expect(repository.standings.value, same(repository.allStandings));
  });
}
