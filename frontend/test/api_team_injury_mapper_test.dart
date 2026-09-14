import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_mapper.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';

void main() {
  test('maps players and all of their injuries without reducing the list', () {
    const response = ApiTeamInjuriesResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiInjuredPlayerResponse(
          playerId: 1001,
          playerName: 'Injured Player',
          playerImage: null,
          jerseyNumber: null,
          injuries: [
            ApiInjuryResponse(
              sidelineId: 5001,
              typeId: 2,
              typeName: 'Hamstring',
              startDate: '2026-08-01',
              endDate: '2026-09-01',
            ),
            ApiInjuryResponse(
              sidelineId: 5002,
              typeId: 3,
              typeName: 'Knock',
              startDate: null,
              endDate: null,
            ),
          ],
        ),
      ],
    );

    final report = teamInjuryReportFromApiResponse(response);

    expect(report.teamId, 83);
    expect(report.seasonId, 25659);
    expect(report.players.single.injuries, hasLength(2));
    expect(
      report.players.single.injuries.first.startDate,
      DateTime.utc(2026, 8, 1),
    );
    expect(
      report.players.single.injuries.first.endDate,
      DateTime.utc(2026, 9, 1),
    );
    expect(report.players.single.injuries.last.endDate, isNull);
  });

  test('rejects malformed and impossible non-null dates', () {
    const malformed = ApiTeamInjuriesResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiInjuredPlayerResponse(
          playerId: 1001,
          playerName: 'Injured Player',
          playerImage: null,
          jerseyNumber: null,
          injuries: [
            ApiInjuryResponse(
              sidelineId: 5001,
              typeId: 2,
              typeName: 'Hamstring',
              startDate: '09/01/2026',
              endDate: null,
            ),
          ],
        ),
      ],
    );
    const impossible = ApiTeamInjuriesResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiInjuredPlayerResponse(
          playerId: 1001,
          playerName: 'Injured Player',
          playerImage: null,
          jerseyNumber: null,
          injuries: [
            ApiInjuryResponse(
              sidelineId: 5001,
              typeId: 2,
              typeName: 'Hamstring',
              startDate: null,
              endDate: '2026-02-30',
            ),
          ],
        ),
      ],
    );

    expect(
      () => teamInjuryReportFromApiResponse(malformed),
      throwsFormatException,
    );
    expect(
      () => teamInjuryReportFromApiResponse(impossible),
      throwsFormatException,
    );
  });
}
