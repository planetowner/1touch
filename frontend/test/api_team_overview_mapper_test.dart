import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_mapper.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_response.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';

void main() {
  test('maps Team overview data and normalizes fixture UTC values', () {
    final overview = teamOverviewFromApiResponse(_response());

    expect(overview.id, 83);
    expect(overview.name, 'FC Barcelona');
    expect(overview.shortName, 'BAR');
    expect(overview.standing?['position'], 1);
    expect(overview.standing?['rank_delta'], -1);
    expect(overview.nextMatch?.fixtureId, 1001);
    expect(overview.nextMatch?.kickoff, DateTime.utc(2026, 9, 20, 15));
    expect(overview.lastMatch, isNull);
  });

  test('preserves optional aggregate absence without inventing data', () {
    final overview = teamOverviewFromApiResponse(
      const ApiTeamOverviewResponse(
        team: ApiTeamResponse(
          teamId: 83,
          name: 'FC Barcelona',
          shortCode: null,
          imagePath: null,
        ),
        nextMatch: null,
        lastMatch: null,
        standing: null,
      ),
    );

    expect(overview.shortName, isEmpty);
    expect(overview.imagePath, isEmpty);
    expect(overview.standing, isNull);
    expect(overview.nextMatch, isNull);
    expect(overview.lastMatch, isNull);
  });

  test('rejects aggregates that belong to another team', () {
    expect(
      () => teamOverviewFromApiResponse(
        _response(
          standingTeamId: 19,
          fixtureHomeTeamId: 83,
          fixtureAwayTeamId: 3468,
        ),
      ),
      throwsStateError,
    );
    expect(
      () => teamOverviewFromApiResponse(
        _response(
          standingTeamId: 83,
          fixtureHomeTeamId: 19,
          fixtureAwayTeamId: 3468,
        ),
      ),
      throwsStateError,
    );
  });
}

ApiTeamOverviewResponse _response({
  int standingTeamId = 83,
  int fixtureHomeTeamId = 83,
  int fixtureAwayTeamId = 3468,
}) {
  return ApiTeamOverviewResponse(
    team: const ApiTeamResponse(
      teamId: 83,
      name: 'FC Barcelona',
      shortCode: 'BAR',
      imagePath: 'https://cdn.example/83.png',
    ),
    nextMatch: ApiFixtureResponse(
      fixtureId: 1001,
      competitionId: 564,
      seasonId: 25659,
      competitionType: 'league',
      roundName: '3',
      stageId: 1,
      stageName: 'Regular Season',
      roundId: 3,
      groupId: null,
      aggregateId: null,
      leg: 'single',
      venueId: null,
      stateId: 1,
      stateCode: 'NS',
      stateName: 'Not Started',
      status: 'upcoming',
      startingAt: '2026-09-20 15:00:00',
      homeTeamId: fixtureHomeTeamId,
      awayTeamId: fixtureAwayTeamId,
      homeScore: null,
      awayScore: null,
      homePenaltyScore: null,
      awayPenaltyScore: null,
      homeTeamName: 'FC Barcelona',
      awayTeamName: 'Girona',
      homeTeamLogo: null,
      awayTeamLogo: null,
    ),
    lastMatch: null,
    standing: ApiTeamOverviewStandingResponse(
      position: 1,
      rankDelta: -1,
      teamId: standingTeamId,
      teamName: 'FC Barcelona',
      teamLogo: null,
      matchesPlayed: 3,
      won: 2,
      draw: 1,
      lost: 0,
      goalsFor: 8,
      goalsAgainst: 2,
      goalDiff: 6,
      points: 7,
      lastFiveForm: const ['W', 'D'],
    ),
  );
}
