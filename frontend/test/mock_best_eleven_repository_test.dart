import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/best_eleven/mock/mock_best_eleven_repository.dart';
import 'package:onetouch/models/best_eleven.dart';

import 'support/best_eleven_repository_contract.dart';

void main() {
  group('MockBestElevenRepository contract', () {
    bestElevenRepositoryContract(
      createRepository: () => MockBestElevenRepository(rows: _rows),
    );
  });

  test('wraps the existing best-eleven catalog', () async {
    final repository = MockBestElevenRepository();
    final lineup = await repository.loadForTeam(9);

    expect(lineup, isNotNull);
    expect(lineup?.players, hasLength(11));
    expect(lineup?.formations, isNotEmpty);
  });
}

final _rows = <BestElevenPlayer>[
  ..._formationRows(
    teamId: 9,
    seasonId: 25583,
    formation: '4-3-3',
  ),
  ..._formationRows(
    teamId: 9,
    seasonId: 25583,
    formation: '3-5-2',
  ).reversed,
  ..._formationRows(
    teamId: 9,
    seasonId: 21646,
    formation: '4-2-3-1',
    playerPrefix: 'Previous',
  ),
];

List<BestElevenPlayer> _formationRows({
  required int teamId,
  required int seasonId,
  required String formation,
  String? playerPrefix,
}) {
  return List.generate(11, (slotIndex) {
    final prefix = playerPrefix ?? formation;
    return BestElevenPlayer(
      id: Object.hash(teamId, seasonId, formation, slotIndex),
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
      slotKey: '${slotIndex + 1}:1',
      slotIndex: slotIndex,
      playerId: seasonId + slotIndex,
      playerName: '$prefix Player $slotIndex',
      playerImage: 'player-$slotIndex.png',
      positionName: slotIndex == 0 ? 'Goalkeeper' : 'Outfield',
      detailedPositionName: slotIndex == 0 ? 'Goalkeeper' : 'Centre Back',
      starts: 10 - slotIndex,
      totalMinutes: (10 - slotIndex) * 90,
      updatedAt: '2026-01-01 00:00:00',
    );
  });
}
