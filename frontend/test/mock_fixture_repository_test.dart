import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/mock/team_season_catalog.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';

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

  test('loads only explicitly supplied fixture detail', () async {
    const fixture = Fixture(
      fixtureId: 1001,
      seasonId: 25583,
      competitionId: 8,
      homeTeamId: 8,
      awayTeamId: 19,
      competitionType: CompetitionType.league,
      roundName: '3',
      status: FixtureStatus.past,
      startingAt: '2026-08-29 14:00:00',
      homeScore: 2,
      awayScore: 1,
    );
    final suppliedDetail = FixtureDetail(
      fixture: fixture,
      venueName: 'Anfield',
      expectedGoals: null,
      playerExpectedGoals: const [],
      shots: const [],
      events: const [],
      statistics: const [],
      lineups: const [],
      formations: const [],
      coaches: const [],
      pressure: const [],
    );
    final repository = MockFixtureRepository(
      fixtures: const [fixture],
      fixtureDetails: [suppliedDetail],
    );

    expect(await repository.loadDetail(1001), same(suppliedDetail));
    await expectLater(repository.loadDetail(9999), throwsStateError);
  });

  test('does not invent detail for a fixture in the base catalog', () async {
    final repository = MockFixtureRepository();

    await expectLater(
      repository.loadDetail(mockFixtures.first.fixtureId),
      throwsStateError,
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

  test('keeps fixture dates, memberships, and scores internally consistent',
      () {
    final seasonsById = {
      for (final season in mockSeasons) season.seasonId: season,
    };
    final membershipKeys = {
      for (final membership in mockTeamSeasonMemberships)
        (
          membership.teamId,
          membership.seasonId,
          membership.competitionId,
        ),
    };

    for (final fixture in mockFixtures) {
      expect(
        seasonsById,
        contains(fixture.seasonId),
        reason: 'fixture ${fixture.fixtureId} has an unknown season',
      );
      final season = seasonsById[fixture.seasonId]!;
      expect(
        season.competitionId,
        fixture.competitionId,
        reason: 'fixture ${fixture.fixtureId} has a mismatched competition',
      );

      if (fixture.status != FixtureStatus.live) {
        final kickoff = fixture.kickoff;
        expect(
          kickoff,
          isNotNull,
          reason: 'mock fixture ${fixture.fixtureId} needs a kickoff',
        );
        final seasonStart = DateTime.parse(season.startingAt);
        final seasonEnd = DateTime.parse(season.endingAt);
        final kickoffDate = DateTime(
          kickoff!.year,
          kickoff.month,
          kickoff.day,
        );
        final startDate = DateTime(
          seasonStart.year,
          seasonStart.month,
          seasonStart.day,
        );
        final endDate = DateTime(
          seasonEnd.year,
          seasonEnd.month,
          seasonEnd.day,
        );

        expect(
          kickoffDate.isBefore(startDate),
          isFalse,
          reason: 'fixture ${fixture.fixtureId} starts before its season',
        );
        expect(
          kickoffDate.isAfter(endDate),
          isFalse,
          reason: 'fixture ${fixture.fixtureId} ends after its season',
        );
      }

      if (fixture.competitionType == CompetitionType.league) {
        expect(
          membershipKeys,
          contains((
            fixture.homeTeamId,
            fixture.seasonId,
            fixture.competitionId,
          )),
          reason: 'fixture ${fixture.fixtureId} has an invalid home team',
        );
        expect(
          membershipKeys,
          contains((
            fixture.awayTeamId,
            fixture.seasonId,
            fixture.competitionId,
          )),
          reason: 'fixture ${fixture.fixtureId} has an invalid away team',
        );
      }

      if (fixture.status == FixtureStatus.upcoming) {
        expect(fixture.homeScore, isNull);
        expect(fixture.awayScore, isNull);
      } else {
        expect(fixture.homeScore, isNotNull);
        expect(fixture.awayScore, isNotNull);
      }
    }
  });

  test('stores undated fixtures last and skips them for next and last', () {
    const fixtures = [
      Fixture(
        fixtureId: 4,
        seasonId: 1,
        competitionId: 8,
        homeTeamId: 1,
        awayTeamId: 2,
        competitionType: CompetitionType.league,
        roundName: null,
        status: FixtureStatus.upcoming,
        startingAt: null,
      ),
      Fixture(
        fixtureId: 2,
        seasonId: 1,
        competitionId: 8,
        homeTeamId: 1,
        awayTeamId: 2,
        competitionType: CompetitionType.league,
        roundName: '1',
        status: FixtureStatus.past,
        startingAt: null,
        homeScore: 1,
        awayScore: 0,
      ),
      Fixture(
        fixtureId: 3,
        seasonId: 1,
        competitionId: 8,
        homeTeamId: 1,
        awayTeamId: 2,
        competitionType: CompetitionType.league,
        roundName: '3',
        status: FixtureStatus.upcoming,
        startingAt: '2026-08-15 15:00:00',
      ),
      Fixture(
        fixtureId: 1,
        seasonId: 1,
        competitionId: 8,
        homeTeamId: 1,
        awayTeamId: 2,
        competitionType: CompetitionType.league,
        roundName: '2',
        status: FixtureStatus.past,
        startingAt: '2026-08-01 15:00:00',
        homeScore: 2,
        awayScore: 1,
      ),
    ];
    final repository = MockFixtureRepository(fixtures: fixtures);

    expect(
      repository.allFixtures.map((fixture) => fixture.fixtureId),
      [1, 3, 2, 4],
    );
    expect(repository.nextForTeam(1)?.fixtureId, 3);
    expect(repository.lastForTeam(1)?.fixtureId, 1);
    expect(
      repository.headToHead(1, 2).map((fixture) => fixture.fixtureId),
      [1, 2],
    );
  });
}
