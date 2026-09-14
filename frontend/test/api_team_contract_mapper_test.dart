import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_mapper.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';
import 'package:onetouch/models/team_contract_roster.dart';

void main() {
  test('maps player identity, metadata, and contract dates', () {
    const response = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      isCurrent: true,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: 'https://example.com/player.png',
          positionGroupId: 27,
          jerseyNumber: 10,
          dateOfBirth: '1998-05-12',
          estimatedWeeklyGrossEur: 125000,
          leadershipRole: 'captain',
          startDate: '2025-07-01',
          endDate: '2028-06-30',
        ),
      ],
    );

    final roster = teamContractRosterFromApiResponse(response);
    final player = roster.players.single;

    expect(roster.teamId, 83);
    expect(roster.seasonId, 25659);
    expect(roster.isCurrent, isTrue);
    expect(player.playerId, 1001);
    expect(player.playerImage, 'https://example.com/player.png');
    expect(player.positionGroup, TeamPositionGroup.forward);
    expect(player.jerseyNumber, 10);
    expect(player.dateOfBirth, DateTime.utc(1998, 5, 12));
    expect(player.estimatedWeeklyGrossEur, 125000);
    expect(player.leadershipRole, TeamLeadershipRole.captain);
    expect(player.startDate, DateTime.utc(2025, 7, 1));
    expect(player.endDate, DateTime.utc(2028, 6, 30));
  });

  test('preserves nullable contract fields', () {
    const response = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      isCurrent: false,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          positionGroupId: null,
          jerseyNumber: null,
          dateOfBirth: null,
          estimatedWeeklyGrossEur: null,
          leadershipRole: null,
          startDate: null,
          endDate: null,
        ),
      ],
    );

    final roster = teamContractRosterFromApiResponse(response);
    final player = roster.players.single;

    expect(roster.isCurrent, isFalse);
    expect(player.playerImage, isNull);
    expect(player.positionGroup, isNull);
    expect(player.jerseyNumber, isNull);
    expect(player.dateOfBirth, isNull);
    expect(player.estimatedWeeklyGrossEur, isNull);
    expect(player.leadershipRole, isNull);
    expect(player.startDate, isNull);
    expect(player.endDate, isNull);
  });

  test('rejects malformed and impossible non-null dates', () {
    const malformed = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      isCurrent: true,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          positionGroupId: null,
          jerseyNumber: null,
          dateOfBirth: null,
          estimatedWeeklyGrossEur: null,
          leadershipRole: null,
          startDate: '07/01/2025',
          endDate: null,
        ),
      ],
    );
    const impossible = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      isCurrent: true,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          positionGroupId: null,
          jerseyNumber: null,
          dateOfBirth: null,
          estimatedWeeklyGrossEur: null,
          leadershipRole: null,
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

  test('rejects unknown non-null position and leadership values', () {
    const unknownPosition = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      isCurrent: true,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          positionGroupId: 99,
          jerseyNumber: null,
          dateOfBirth: null,
          estimatedWeeklyGrossEur: null,
          leadershipRole: null,
          startDate: null,
          endDate: null,
        ),
      ],
    );
    const unknownLeadership = ApiTeamContractsResponse(
      teamId: 83,
      seasonId: 25659,
      isCurrent: true,
      players: [
        ApiPlayerContractResponse(
          playerId: 1001,
          playerName: 'Contract Player',
          playerImage: null,
          positionGroupId: null,
          jerseyNumber: null,
          dateOfBirth: null,
          estimatedWeeklyGrossEur: null,
          leadershipRole: 'manager',
          startDate: null,
          endDate: null,
        ),
      ],
    );

    expect(
      () => teamContractRosterFromApiResponse(unknownPosition),
      throwsFormatException,
    );
    expect(
      () => teamContractRosterFromApiResponse(unknownLeadership),
      throwsFormatException,
    );
  });
}
