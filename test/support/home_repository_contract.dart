import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/models/fixture.dart';

void homeRepositoryContract({
  required HomeRepository Function() createRepository,
}) {
  late HomeRepository repository;

  setUp(() => repository = createRepository());

  test('loads the favorite, following teams, and nearest fixtures', () async {
    final home = await repository.load(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );

    expect(home.favoriteTeam?.teamId, 1);
    expect(home.followingTeams.map((team) => team.teamId), [1, 2]);
    expect(home.nextMatch?.fixtureId, 3);
    expect(home.lastMatch?.fixtureId, 1);
  });

  test('loads an inclusive calendar newest first and derives live match',
      () async {
    final home = await repository.load(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );

    expect(
      home.calendar.map((fixture) => fixture.fixtureId),
      [3, 2, 1],
    );
    expect(home.liveMatch?.fixtureId, 2);
  });

  test('omits the calendar when no date boundary is requested', () async {
    final home = await repository.load();

    expect(home.calendar, isEmpty);
    expect(home.liveMatch, isNull);
  });

  test('does not expose mutable response lists', () async {
    final home = await repository.load(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );

    expect(() => home.followingTeams.clear(), throwsUnsupportedError);
    expect(() => home.calendar.clear(), throwsUnsupportedError);
  });

  test('keeps non-favorite fixtures out of the home calendar', () async {
    final home = await repository.load(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );

    expect(
      home.calendar.every(
        (fixture) => fixture.homeTeamId == 1 || fixture.awayTeamId == 1,
      ),
      isTrue,
    );
    expect(
      home.calendar.where((fixture) => fixture.status == FixtureStatus.live),
      hasLength(1),
    );
  });
}
