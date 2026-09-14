import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_response.dart';

void main() {
  test('maps and orders xG standings without inventing W/D/L values', () {
    final standings = xgStandingsFromApiResponse(
      ApiCompetitionXgStandingsResponse(
        competitionId: 8,
        seasonId: 25583,
        provider: 'understat',
        xptsMethod: 'historical_draw_rate',
        rows: [
          _row(position: 2, teamId: 19, teamName: 'Arsenal'),
          _row(position: 1, teamId: 9, teamName: 'Manchester City'),
        ],
      ),
    );

    expect(standings.map((row) => row.teamId), [9, 19]);
    expect(standings.first.teamName, 'Manchester City');
    expect(standings.first.teamLogo, isNull);
    expect(standings.first.won, isNull);
    expect(standings.first.draw, isNull);
    expect(standings.first.lost, isNull);
    expect(standings.first.provider, 'understat');
    expect(standings.first.xptsMethod, 'historical_draw_rate');
    expect(() => standings.clear(), throwsUnsupportedError);
  });

  test('rejects duplicate team and position identities', () {
    expect(
      () => xgStandingsFromApiResponse(
        _response([
          _row(position: 1, teamId: 9, teamName: 'Manchester City'),
          _row(position: 2, teamId: 9, teamName: 'Manchester City'),
        ]),
      ),
      throwsStateError,
    );
    expect(
      () => xgStandingsFromApiResponse(
        _response([
          _row(position: 1, teamId: 9, teamName: 'Manchester City'),
          _row(position: 1, teamId: 19, teamName: 'Arsenal'),
        ]),
      ),
      throwsStateError,
    );
  });
}

ApiCompetitionXgStandingsResponse _response(
  List<ApiXgStandingRowResponse> rows,
) {
  return ApiCompetitionXgStandingsResponse(
    competitionId: 8,
    seasonId: 25583,
    provider: 'understat',
    xptsMethod: 'historical_draw_rate',
    rows: rows,
  );
}

ApiXgStandingRowResponse _row({
  required int position,
  required int teamId,
  required String teamName,
}) {
  return ApiXgStandingRowResponse(
    position: position,
    teamId: teamId,
    teamName: teamName,
    teamLogo: null,
    matchesPlayed: 3,
    xg: 8.125,
    xga: 2.5,
    xpts: 7.25,
  );
}
