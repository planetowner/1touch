import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/competition_repository.dart';
import 'package:onetouch/models/competition.dart';

void competitionRepositoryContract({
  required CompetitionRepository Function(
    List<Competition> competitions,
    Set<int> domesticCompetitionIds,
  ) createRepository,
}) {
  const competitions = <Competition>[
    Competition(competitionId: 8, name: 'Premier League'),
    Competition(competitionId: 2, name: 'UEFA Champions League'),
    Competition(competitionId: 82, name: 'Bundesliga'),
  ];
  const domesticCompetitionIds = <int>{8, 82};

  late CompetitionRepository repository;

  setUp(() {
    repository = createRepository(
      competitions,
      domesticCompetitionIds,
    );
  });

  test('preserves the competition catalog order', () {
    expect(
      repository.allCompetitions.map(
        (competition) => competition.competitionId,
      ),
      [8, 2, 82],
    );
  });

  test('finds competitions by ID without inventing unknown entities', () {
    expect(repository.findById(2), same(competitions[1]));
    expect(repository.findById(-1), isNull);
  });

  test('distinguishes present and absent competition IDs', () {
    expect(repository.contains(8), isTrue);
    expect(repository.contains(-1), isFalse);
  });

  test('returns only supported domestic competitions in catalog order', () {
    expect(
      repository.domesticCompetitions.map(
        (competition) => competition.competitionId,
      ),
      [8, 82],
    );
  });

  test('does not expose mutable competition lists', () {
    expect(
      () => repository.allCompetitions.add(competitions.first),
      throwsUnsupportedError,
    );
    expect(
      () => repository.domesticCompetitions.clear(),
      throwsUnsupportedError,
    );
  });

  test('keeps the listenable cache consistent after initialization', () async {
    await repository.initialize();

    expect(repository.competitions.value, same(repository.allCompetitions));
  });
}
