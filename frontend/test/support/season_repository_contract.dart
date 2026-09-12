import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/seasons/season_repository.dart';
import 'package:onetouch/models/season.dart';

void seasonRepositoryContract({
  required SeasonRepository Function(List<Season> seasons) createRepository,
}) {
  const seasons = <Season>[
    Season(
      seasonId: 200,
      competitionId: 8,
      name: '2024/2025',
      isCurrent: false,
      startingAt: '2024-08-16 00:00:00',
      endingAt: '2025-05-25 00:00:00',
    ),
    Season(
      seasonId: 300,
      competitionId: 82,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-22 00:00:00',
      endingAt: '2026-05-16 00:00:00',
    ),
    Season(
      seasonId: 100,
      competitionId: 8,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-15 00:00:00',
      endingAt: '2026-05-24 00:00:00',
    ),
  ];

  late SeasonRepository repository;

  setUp(() {
    repository = createRepository(seasons);
  });

  test('preserves the season catalog order', () {
    expect(
      repository.allSeasons.map((season) => season.seasonId),
      [200, 300, 100],
    );
  });

  test('finds seasons by ID without inventing unknown entities', () {
    expect(repository.findById(300), same(seasons[1]));
    expect(repository.findById(-1), isNull);
  });

  test('distinguishes present and absent season IDs', () {
    expect(repository.contains(100), isTrue);
    expect(repository.contains(-1), isFalse);
  });

  test('returns competition seasons in catalog order', () {
    expect(
      repository.forCompetition(8).map((season) => season.seasonId),
      [200, 100],
    );
    expect(repository.forCompetition(-1), isEmpty);
  });

  test('returns the flagged current season without guessing', () {
    expect(repository.currentForCompetition(8), same(seasons[2]));
    expect(repository.currentForCompetition(-1), isNull);
  });

  test('does not expose mutable season lists', () {
    expect(
      () => repository.allSeasons.add(seasons.first),
      throwsUnsupportedError,
    );
    expect(
      () => repository.forCompetition(8).clear(),
      throwsUnsupportedError,
    );
  });

  test('keeps the listenable cache consistent after initialization', () async {
    await repository.initialize();

    expect(repository.seasons.value, same(repository.allSeasons));
  });
}
