import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';

void main() {
  test('parses the verified team-contracts response', () {
    final response = ApiTeamContractsResponse.fromJson(_rosterJson());

    expect(response.teamId, 83);
    expect(response.seasonId, 25659);
    expect(response.isCurrent, isTrue);
    expect(response.players.single.playerId, 1001);
    expect(response.players.single.playerName, 'Contract Player');
    expect(response.players.single.positionGroupId, 27);
    expect(response.players.single.dateOfBirth, '1998-05-12');
    expect(response.players.single.estimatedWeeklyGrossEur, 125000);
    expect(response.players.single.leadershipRole, 'captain');
    expect(response.players.single.startDate, '2025-07-01');
    expect(response.players.single.endDate, '2028-06-30');
  });

  test('preserves every documented nullable player-contract field', () {
    final player = ApiTeamContractsResponse.fromJson({
      'team_id': 83,
      'season_id': 25659,
      'is_current': false,
      'players': [
        {
          'player_id': 1001,
          'player_name': 'Contract Player',
          'player_image': null,
          'position_group_id': null,
          'jersey_number': null,
          'date_of_birth': null,
          'estimated_weekly_gross_eur': null,
          'leadership_role': null,
          'start_date': null,
          'end_date': null,
        },
      ],
    }).players.single;

    expect(player.playerImage, isNull);
    expect(player.positionGroupId, isNull);
    expect(player.jerseyNumber, isNull);
    expect(player.dateOfBirth, isNull);
    expect(player.estimatedWeeklyGrossEur, isNull);
    expect(player.leadershipRole, isNull);
    expect(player.startDate, isNull);
    expect(player.endDate, isNull);
  });

  test('rejects malformed required, nullable, and nested fields', () {
    final malformedName = _rosterJson();
    final malformedNamePlayer = Map<String, dynamic>.from(
      (malformedName['players'] as List).single as Map,
    )..['player_name'] = null;
    malformedName['players'] = [malformedNamePlayer];

    final malformedJersey = _rosterJson();
    final malformedJerseyPlayer = Map<String, dynamic>.from(
      (malformedJersey['players'] as List).single as Map,
    )..['jersey_number'] = '10';
    malformedJersey['players'] = [malformedJerseyPlayer];

    final malformedPlayers = _rosterJson()..['players'] = [1];

    final malformedCurrent = _rosterJson()..['is_current'] = 1;

    final malformedLeadership = _rosterJson();
    final malformedLeadershipPlayer = Map<String, dynamic>.from(
      (malformedLeadership['players'] as List).single as Map,
    )..['leadership_role'] = 'manager';
    malformedLeadership['players'] = [malformedLeadershipPlayer];

    expect(
      () => ApiTeamContractsResponse.fromJson(malformedName),
      throwsFormatException,
    );
    expect(
      () => ApiTeamContractsResponse.fromJson(malformedJersey),
      throwsFormatException,
    );
    expect(
      () => ApiTeamContractsResponse.fromJson(malformedPlayers),
      throwsFormatException,
    );
    expect(
      () => ApiTeamContractsResponse.fromJson(malformedCurrent),
      throwsFormatException,
    );
    expect(
      () => ApiTeamContractsResponse.fromJson(malformedLeadership),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _rosterJson() => {
      'team_id': 83,
      'season_id': 25659,
      'is_current': true,
      'players': [
        {
          'player_id': 1001,
          'player_name': 'Contract Player',
          'player_image': 'https://example.com/player.png',
          'position_group_id': 27,
          'jersey_number': 10,
          'date_of_birth': '1998-05-12',
          'estimated_weekly_gross_eur': 125000,
          'leadership_role': 'captain',
          'start_date': '2025-07-01',
          'end_date': '2028-06-30',
        },
      ],
    };
