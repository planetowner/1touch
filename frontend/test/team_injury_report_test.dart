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

  test('counts calendar days without shifting the provider end date', () {
    final injury = TeamPlayerInjury(
      sidelineId: 5001,
      typeId: 535,
      typeName: 'Hamstring injury',
      endDate: DateTime.utc(2026, 11, 2),
    );

    expect(injury.daysUntilReturn(DateTime(2026, 9, 21, 23, 59)), 42);
    expect(injury.daysUntilReturn(DateTime(2026, 11, 1, 23, 59)), 1);
    expect(injury.daysUntilReturn(DateTime(2026, 11, 2, 23, 59)), 0);
    expect(injury.daysUntilReturn(DateTime(2026, 11, 3)), -1);
    expect(
        _report()
            .players
            .single
            .injuries
            .single
            .daysUntilReturn(DateTime(2026, 9, 24)),
        isNull);
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
