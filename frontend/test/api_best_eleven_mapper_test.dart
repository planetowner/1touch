import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_mapper.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_response.dart';

void main() {
  test('maps the complete response without changing list order', () {
    const response = ApiBestElevenResponse(
      teamId: 83,
      seasonId: 25659,
      formation: '4-3-3',
      matchesUsed: 20,
      totalValidMatches: 30,
      usagePercentage: 66.67,
      formations: [
        ApiBestElevenFormationResponse(
          formation: '4-3-3',
          matchesUsed: 20,
          totalValidMatches: 30,
          usagePercentage: 66.67,
          isDefault: true,
        ),
        ApiBestElevenFormationResponse(
          formation: '4-2-3-1',
          matchesUsed: 10,
          totalValidMatches: 30,
          usagePercentage: 33.33,
          isDefault: false,
        ),
      ],
      players: [
        ApiBestElevenPlayerResponse(
          slotKey: '1:1',
          slotIndex: 0,
          playerId: 1,
          playerName: null,
          playerImage: null,
          positionGroupCode: 'GK',
          positionCode: 'GK',
          starts: 20,
        ),
        ApiBestElevenPlayerResponse(
          slotKey: '2:1',
          slotIndex: 1,
          playerId: 2,
          playerName: 'Defender',
          playerImage: 'https://example.com/2.png',
          positionGroupCode: 'DEF',
          positionCode: 'LB',
          starts: 18,
          jerseyNumber: 27,
        ),
      ],
    );

    final result = teamBestElevenFromApiResponse(response);

    expect(result.teamId, 83);
    expect(result.seasonId, 25659);
    expect(result.formation, '4-3-3');
    expect(result.matchesUsed, 20);
    expect(result.totalValidMatches, 30);
    expect(result.usagePercentage, 66.67);
    expect(
      result.formations.map((option) => option.formation),
      ['4-3-3', '4-2-3-1'],
    );
    expect(result.players.map((player) => player.slotKey), ['1:1', '2:1']);
    expect(result.players.first.playerName, isNull);
    expect(result.players.last.positionGroupCode, 'DEF');
    expect(result.players.last.positionCode, 'LB');
    expect(result.players.last.jerseyNumber, 27);
    expect(result.players.first.jerseyNumber, isNull);
    expect(() => result.players.clear(), throwsUnsupportedError);
  });
}
