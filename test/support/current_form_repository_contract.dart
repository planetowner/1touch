import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';

void currentFormRepositoryContract({
  required CurrentFormRepository Function() createRepository,
}) {
  late CurrentFormRepository repository;

  setUp(() => repository = createRepository());

  test('starts without inventing cached options or comparisons', () {
    expect(repository.cachedOptions.value, isEmpty);
    expect(repository.cachedComparisons.value, isEmpty);
    expect(repository.cachedOptionsFor(1), isNull);
    expect(
      repository.cachedComparisonFor(
        1,
        compareTeamId: 2,
        compareSeasonId: 100,
      ),
      isNull,
    );
  });

  test('loads searchable options with their own team and season identity',
      () async {
    final options = await repository.loadOptions(1, search: 'beta');

    expect(options, hasLength(1));
    expect(options.single.teamId, 2);
    expect(options.single.teamName, 'Beta FC');
    expect(options.single.leagueId, 8);
    expect(options.single.seasonId, 100);
    expect(options.single.seasonName, '2025/26');
    expect(options.single.roundsAvailable, greaterThan(0));
  });

  test('normalizes option queries and keeps limits separate', () async {
    final first = await repository.loadOptions(1, search: ' BETA ', limit: 10);
    final repeated = await repository.loadOptions(
      1,
      search: 'beta',
      limit: 10,
    );
    final limited = await repository.loadOptions(1, limit: 1);

    expect(repeated, same(first));
    expect(limited, hasLength(1));
    expect(repository.cachedOptions.value, hasLength(2));
  });

  test('rejects option limits outside the backend contract', () async {
    expect(() => repository.loadOptions(1, limit: 0), throwsRangeError);
    expect(() => repository.loadOptions(1, limit: 101), throwsRangeError);
  });

  test('loads one current series against one selected comparison', () async {
    final comparison = await repository.loadComparison(
      1,
      compareTeamId: 2,
      compareSeasonId: 100,
    );

    expect(comparison, isNotNull);
    expect(comparison?.current.teamId, 1);
    expect(comparison?.current.seasonId, 100);
    expect(comparison?.comparison.teamId, 2);
    expect(comparison?.comparison.teamName, 'Beta FC');
    expect(comparison?.comparison.seasonId, 100);
    expect(comparison?.maxRound, greaterThan(0));
    expect(comparison?.maxPoints, greaterThan(0));
  });

  test('keeps current-season and comparison selections query-specific',
      () async {
    final current = await repository.loadComparison(
      1,
      compareTeamId: 2,
      compareSeasonId: 100,
    );
    final previous = await repository.loadComparison(
      1,
      seasonId: 90,
      compareTeamId: 1,
      compareSeasonId: 90,
    );

    expect(current?.current.seasonId, 100);
    expect(previous?.current.seasonId, 90);
    expect(repository.cachedComparisons.value, hasLength(2));
  });

  test('returns empty or null when the requested data is unavailable',
      () async {
    expect(await repository.loadOptions(-1), isEmpty);
    expect(
      await repository.loadComparison(
        -1,
        compareTeamId: 2,
        compareSeasonId: 100,
      ),
      isNull,
    );
    expect(
      await repository.loadComparison(
        1,
        compareTeamId: 2,
        compareSeasonId: -1,
      ),
      isNull,
    );
    expect(repository.cachedComparisons.value, isEmpty);
  });

  test('publishes immutable cached maps, options, and point lists', () async {
    final options = await repository.loadOptions(1);
    final comparison = await repository.loadComparison(
      1,
      compareTeamId: 2,
      compareSeasonId: 100,
    );

    expect(
        () => repository.cachedOptions.value.clear(), throwsUnsupportedError);
    expect(() => options.clear(), throwsUnsupportedError);
    expect(
      () => repository.cachedComparisons.value.clear(),
      throwsUnsupportedError,
    );
    expect(() => comparison?.current.points.clear(), throwsUnsupportedError);
  });

  test('reuses a cached comparison for repeated loads', () async {
    final first = await repository.loadComparison(
      1,
      compareTeamId: 2,
      compareSeasonId: 100,
    );
    final second = await repository.loadComparison(
      1,
      compareTeamId: 2,
      compareSeasonId: 100,
    );

    expect(second, same(first));
  });
}
