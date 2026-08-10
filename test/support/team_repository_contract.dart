import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/team_repository.dart';

void teamRepositoryContract({
  required TeamRepository Function() createRepository,
  required int expectedTeamCount,
  required int knownTeamId,
  required String knownTeamName,
  required String nameQuery,
  required String shortCodeQuery,
}) {
  late TeamRepository repository;

  setUp(() => repository = createRepository());

  test('provides the expected team catalog', () {
    expect(repository.allTeams, hasLength(expectedTeamCount));
  });

  test('finds a known team by ID', () {
    final team = repository.findById(knownTeamId);

    expect(team?.teamId, knownTeamId);
    expect(team?.name, knownTeamName);
  });

  test('returns null for an unknown team ID', () {
    expect(repository.findById(-1), isNull);
  });

  test('makes required-team invariants explicit', () {
    expect(
      repository.requireById(knownTeamId),
      same(repository.findById(knownTeamId)),
    );
    expect(() => repository.requireById(-1), throwsStateError);
  });

  test('provides an explicit fallback for embedded team references', () {
    expect(
      repository.findByIdOrUnknown(knownTeamId),
      same(repository.findById(knownTeamId)),
    );

    final unknown = repository.findByIdOrUnknown(-1);
    expect(unknown.teamId, -1);
    expect(unknown.name, 'Unknown Team');
    expect(unknown.imagePath, isNull);
  });

  test('distinguishes present and absent team IDs', () {
    expect(repository.contains(knownTeamId), isTrue);
    expect(repository.contains(-1), isFalse);
  });

  test('searches by team name and short code', () {
    expect(
      repository.search(nameQuery).map((team) => team.teamId),
      contains(knownTeamId),
    );
    expect(
      repository.search(shortCodeQuery).map((team) => team.teamId),
      contains(knownTeamId),
    );
  });

  test('normalizes search case and surrounding whitespace', () {
    expect(
      repository.search('  ${nameQuery.toUpperCase()}  ').map(
            (team) => team.teamId,
          ),
      contains(knownTeamId),
    );
  });

  test('does not expose mutable result lists', () {
    expect(
      () => repository.allTeams.add(repository.allTeams.first),
      throwsUnsupportedError,
    );
    expect(
      () => repository.search(nameQuery).clear(),
      throwsUnsupportedError,
    );
  });

  test('keeps the listenable cache consistent after initialization', () async {
    await repository.initialize();

    expect(repository.teams.value, same(repository.allTeams));
  });
}
