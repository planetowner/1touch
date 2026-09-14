import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_mapper.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';

void main() {
  test('maps player identity, metadata, and contract dates', () {
    const response = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: 'https://example.com/player.png',
          jerseyNumber: 10,
          startDate: '2025-07-01',
          endDate: '2028-06-30',
        ),
      ],
    );

    final roster = teamContractRosterFromApiResponse(response);
    final player = roster.players.single;

    expect(roster.teamId, 83);
    expect(roster.seasonId, 25659);
    expect(player.playerId, 1001);
    expect(player.playerImage, 'https://example.com/player.png');
    expect(player.jerseyNumber, 10);
    expect(player.startDate, DateTime.utc(2025, 7, 1));
    expect(player.endDate, DateTime.utc(2028, 6, 30));
  });

  test('preserves nullable contract fields', () {
    const response = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          jerseyNumber: null,
          startDate: null,
          endDate: null,
        ),
      ],
    );

    final player = teamContractRosterFromApiResponse(response).players.single;

    expect(player.playerImage, isNull);
    expect(player.jerseyNumber, isNull);
    expect(player.startDate, isNull);
    expect(player.endDate, isNull);
  });

  test('rejects malformed and impossible non-null dates', () {
    const malformed = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          jerseyNumber: null,
          startDate: '07/01/2025',
          endDate: null,
        ),
      ],
    );
    const impossible = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          jerseyNumber: null,
          startDate: null,
          endDate: '2026-02-30',
        ),
      ],
    );

    expect(
      () => teamContractRosterFromApiResponse(malformed),
      throwsFormatException,
    );
    expect(
      () => teamContractRosterFromApiResponse(impossible),
      throwsFormatException,
    );
  });
}
