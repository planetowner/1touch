import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/team_injury_report.dart';

void main() {
  test('preserves required injury and player identity', () {
    final report = _report();

    expect(report.teamId, 83);
    expect(report.seasonId, 25659);
    expect(report.players.single.playerId, 1001);
    expect(report.players.single.playerName, 'Injured Player');
    expect(report.players.single.injuries.single.sidelineId, 5001);
    expect(report.players.single.injuries.single.typeName, 'Hamstring');
  });

  test('supports documented nullable player and injury fields', () {
    final player = _report().players.single;
    final injury = player.injuries.single;

    expect(player.playerImage, isNull);
    expect(player.jerseyNumber, isNull);
    expect(injury.startDate, isNull);
    expect(injury.endDate, isNull);
  });

  test('publishes immutable player and nested injury lists', () {
    final report = _report();

    expect(() => report.players.clear(), throwsUnsupportedError);
    expect(
      () => report.players.single.injuries.clear(),
      throwsUnsupportedError,
    );
  });
}

TeamInjuryReport _report() {
  return TeamInjuryReport(
    teamId: 83,
    seasonId: 25659,
    players: [
      InjuredTeamPlayer(
        playerId: 1001,
        playerName: 'Injured Player',
        injuries: const [
          TeamPlayerInjury(
            sidelineId: 5001,
            typeId: 2,
            typeName: 'Hamstring',
          ),
        ],
      ),
    ],
  );
}
