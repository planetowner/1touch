import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/mock/team_season_catalog.dart';
import 'package:onetouch/models/fixture.dart';

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
        final kickoff = DateTime.parse(fixture.startingAt);
        final seasonStart = DateTime.parse(season.startingAt);
        final seasonEnd = DateTime.parse(season.endingAt);
        final kickoffDate = DateTime(kickoff.year, kickoff.month, kickoff.day);
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
}
