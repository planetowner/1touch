import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';

void bestElevenRepositoryContract({
  required BestElevenRepository Function() createRepository,
}) {
  late BestElevenRepository repository;

  setUp(() => repository = createRepository());

  test('starts without inventing a cached lineup', () {
    expect(repository.cachedLineups.value, isEmpty);
    expect(repository.cachedForTeam(9), isNull);
  });

  test('loads the default formation with players in slot order', () async {
    final lineup = await repository.loadForTeam(9, seasonId: 25583);

    expect(lineup, isNotNull);
    expect(lineup?.teamId, 9);
    expect(lineup?.seasonId, 25583);
    expect(lineup?.formation, '4-3-3');
    expect(lineup?.players.map((player) => player.slotIndex),
        List.generate(11, (index) => index));
    expect(lineup?.players.first.playerName, '4-3-3 Player 0');
  });

  test('loads a requested formation as a distinct query', () async {
    final defaultLineup = await repository.loadForTeam(9, seasonId: 25583);
    final alternateLineup = await repository.loadForTeam(
      9,
      seasonId: 25583,
      formation: ' 3-5-2 ',
    );

    expect(alternateLineup?.formation, '3-5-2');
    expect(alternateLineup?.players.first.playerName, '3-5-2 Player 0');
    expect(alternateLineup, isNot(same(defaultLineup)));
    expect(repository.cachedLineups.value, hasLength(2));
    expect(
      repository.cachedForTeam(
        9,
        seasonId: 25583,
        formation: '3-5-2',
      ),
      same(alternateLineup),
    );
  });

  test('exposes only available formations without invented usage data',
      () async {
    final lineup = await repository.loadForTeam(9, seasonId: 25583);

    expect(
      lineup?.formations.map((option) => option.formation),
      ['4-3-3', '3-5-2'],
    );
    expect(lineup?.formations.first.isDefault, isTrue);
    expect(lineup?.matchesUsed, isNull);
    expect(lineup?.totalValidMatches, isNull);
    expect(lineup?.usagePercentage, isNull);
    expect(lineup?.formations.first.matchesUsed, isNull);
  });

  test('keeps season queries separate', () async {
    final current = await repository.loadForTeam(9, seasonId: 25583);
    final previous = await repository.loadForTeam(9, seasonId: 21646);

    expect(current?.seasonId, 25583);
    expect(previous?.seasonId, 21646);
    expect(previous?.players.first.playerName, 'Previous Player 0');
    expect(repository.cachedLineups.value, hasLength(2));
  });

  test('returns null for unavailable teams, seasons, and formations', () async {
    expect(await repository.loadForTeam(-1), isNull);
    expect(await repository.loadForTeam(9, seasonId: -1), isNull);
    expect(
      await repository.loadForTeam(
        9,
        seasonId: 25583,
        formation: '4-4-2',
      ),
      isNull,
    );
    expect(repository.cachedLineups.value, isEmpty);
  });

  test('publishes immutable cache and result lists', () async {
    final lineup = await repository.loadForTeam(9, seasonId: 25583);

    expect(
      () => repository.cachedLineups.value.clear(),
      throwsUnsupportedError,
    );
    expect(() => lineup?.players.clear(), throwsUnsupportedError);
    expect(() => lineup?.formations.clear(), throwsUnsupportedError);
  });

  test('reuses the cached lineup for repeated loads', () async {
    final first = await repository.loadForTeam(9, seasonId: 25583);
    final second = await repository.loadForTeam(9, seasonId: 25583);

    expect(second, same(first));
  });
}
