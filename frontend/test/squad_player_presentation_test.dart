import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/team/squad/squad_player_presentation.dart';
import 'package:onetouch/models/team_contract_roster.dart';

void main() {
  group('SquadPlayer.fromContract', () {
    test('maps the API-backed player fields and calculates age', () {
      final player = SquadPlayer.fromContract(
        TeamPlayerContract(
          playerId: 7,
          playerName: 'Player Seven',
          playerImage: 'https://example.com/player.png',
          positionGroup: TeamPositionGroup.defender,
          jerseyNumber: 4,
          dateOfBirth: DateTime.utc(2000, 9, 15),
          estimatedWeeklyGrossEur: 125000,
          leadershipRole: TeamLeadershipRole.viceCaptain,
          endDate: DateTime.utc(2028, 6, 30),
        ),
        teamName: 'FC Example',
        asOf: DateTime.utc(2026, 9, 14),
      );

      expect(player.id, 7);
      expect(player.teamLabel, 'FC Example • 4');
      expect(player.position, Position.DF);
      expect(player.age, 25);
      expect(player.contractEndDate, DateTime.utc(2028, 6, 30));
      expect(player.estimatedWeeklyGrossEur, 125000);
      expect(player.leadershipRole, TeamLeadershipRole.viceCaptain);
    });

    test('preserves unavailable API fields instead of inventing values', () {
      final player = SquadPlayer.fromContract(
        const TeamPlayerContract(
          playerId: 8,
          playerName: 'Unknown Details',
        ),
        teamName: 'FC Example',
        asOf: DateTime.utc(2026, 9, 14),
      );

      expect(player.teamLabel, 'FC Example');
      expect(player.position, isNull);
      expect(player.jerseyNumber, isNull);
      expect(player.age, isNull);
      expect(player.contractEndDate, isNull);
      expect(player.estimatedWeeklyGrossEur, isNull);
      expect(player.leadershipRole, isNull);
    });
  });

  test('age calculation changes on the birthday', () {
    final birthday = DateTime.utc(2000, 9, 15);

    expect(ageAt(birthday, DateTime.utc(2026, 9, 14)), 25);
    expect(ageAt(birthday, DateTime.utc(2026, 9, 15)), 26);
    expect(ageAt(null, DateTime.utc(2026, 9, 15)), isNull);
  });

  test('missing values sort last in both directions', () {
    final missing = SquadPlayer(
      id: 1,
      name: 'Missing',
      teamLabel: 'Team',
    );
    final lower = SquadPlayer(
      id: 2,
      name: 'Lower',
      teamLabel: 'Team',
      jerseyNumber: 4,
      position: Position.DF,
      age: 20,
      contractEndDate: DateTime.utc(2027, 6, 30),
      estimatedWeeklyGrossEur: 1000,
    );
    final higher = SquadPlayer(
      id: 3,
      name: 'Higher',
      teamLabel: 'Team',
      jerseyNumber: 8,
      position: Position.FW,
      age: 30,
      contractEndDate: DateTime.utc(2028, 6, 30),
      estimatedWeeklyGrossEur: 2000,
    );

    for (final option in SortOption.values) {
      final ascending = [missing, higher, lower]
        ..sort((a, b) => compareSquadPlayers(
              a,
              b,
              option: option,
              ascending: true,
            ));
      final descending = [missing, lower, higher]
        ..sort((a, b) => compareSquadPlayers(
              a,
              b,
              option: option,
              ascending: false,
            ));

      expect(ascending.last, same(missing), reason: '$option ascending');
      expect(descending.last, same(missing), reason: '$option descending');
      expect(ascending.first, same(lower), reason: '$option ascending');
      expect(descending.first, same(higher), reason: '$option descending');
    }
  });

  test('contract length is unavailable for historical rosters', () {
    expect(
      availableSquadSortOptions(isCurrent: false),
      isNot(contains(SortOption.contractLength)),
    );
    expect(
      availableSquadSortOptions(isCurrent: true),
      contains(SortOption.contractLength),
    );
  });
}
