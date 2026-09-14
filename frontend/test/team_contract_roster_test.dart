import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/team_contract_roster.dart';

void main() {
  test('preserves required roster and player identity', () {
    final roster = _roster();
    final player = roster.players.single;

    expect(roster.teamId, 83);
    expect(roster.seasonId, 25659);
    expect(roster.isCurrent, isTrue);
    expect(player.playerId, 1001);
    expect(player.playerName, 'Contract Player');
  });

  test('supports every documented nullable contract field', () {
    final player = _roster().players.single;

    expect(player.playerImage, isNull);
    expect(player.positionGroup, isNull);
    expect(player.jerseyNumber, isNull);
    expect(player.dateOfBirth, isNull);
    expect(player.estimatedWeeklyGrossEur, isNull);
    expect(player.leadershipRole, isNull);
    expect(player.startDate, isNull);
    expect(player.endDate, isNull);
  });

  test('publishes an immutable player list', () {
    final roster = _roster();

    expect(() => roster.players.clear(), throwsUnsupportedError);
  });
}

TeamContractRoster _roster() {
  return TeamContractRoster(
    teamId: 83,
    seasonId: 25659,
    isCurrent: true,
    players: const [
      TeamPlayerContract(
        playerId: 1001,
        playerName: 'Contract Player',
      ),
    ],
  );
}
