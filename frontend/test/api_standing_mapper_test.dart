import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/standings/api/api_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_standing_response.dart';
import 'package:onetouch/models/standing.dart';

void main() {
  test('maps and orders regular league standings', () {
    final standings = standingsFromApiResponse(
      ApiCompetitionStandingsResponse(
        competitionId: 8,
        seasonId: 25583,
        rows: [
          _row(position: 2, teamId: 19, teamName: 'Arsenal'),
          _row(position: 1, teamId: 9, teamName: 'Manchester City'),
        ],
      ),
    );

    expect(standings.map((row) => row.teamId), [9, 19]);
    expect(standings.first.competitionId, 8);
    expect(standings.first.seasonId, 25583);
    expect(standings.first.phase, StandingPhase.league);
    expect(standings.first.groupName, isEmpty);
    expect(standings.first.teamName, 'Manchester City');
    expect(standings.first.teamLogo, isNull);
    expect(standings.first.rankDelta, 1);
    expect(() => standings.clear(), throwsUnsupportedError);
  });

  test('rejects duplicate team and position identities', () {
    expect(
      () => standingsFromApiResponse(
        ApiCompetitionStandingsResponse(
          competitionId: 8,
          seasonId: 25583,
          rows: [
            _row(position: 1, teamId: 9, teamName: 'Manchester City'),
            _row(position: 2, teamId: 9, teamName: 'Manchester City'),
          ],
        ),
      ),
      throwsStateError,
    );
    expect(
      () => standingsFromApiResponse(
        ApiCompetitionStandingsResponse(
          competitionId: 8,
          seasonId: 25583,
          rows: [
            _row(position: 1, teamId: 9, teamName: 'Manchester City'),
            _row(position: 1, teamId: 19, teamName: 'Arsenal'),
          ],
        ),
      ),
      throwsStateError,
    );
  });
}

ApiStandingRowResponse _row({
  required int position,
  required int teamId,
  required String teamName,
}) {
  return ApiStandingRowResponse(
    position: position,
    rankDelta: 1,
    teamId: teamId,
    teamName: teamName,
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
  );
}
