import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';

void main() {
  test('parses the verified team-contracts response', () {
    final response = ApiTeamContractsResponse.fromJson(_rosterJson());

    expect(response.teamId, 83);
    expect(response.seasonId, 25659);
    expect(response.players.single.playerId, 1001);
    expect(response.players.single.playerName, 'Contract Player');
    expect(response.players.single.startDate, '2025-07-01');
    expect(response.players.single.endDate, '2028-06-30');
  });

  test('preserves every documented nullable player-contract field', () {
    final player = ApiTeamContractsResponse.fromJson({
      'team_id': 83,
      'season_id': 25659,
      'players': [
        {
          'player_id': 1001,
          'player_name': 'Contract Player',
          'player_image': null,
          'jersey_number': null,
          'start_date': null,
          'end_date': null,
        },
      ],
    }).players.single;

    expect(player.playerImage, isNull);
    expect(player.jerseyNumber, isNull);
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
  });
}

Map<String, dynamic> _rosterJson() => {
      'team_id': 83,
      'season_id': 25659,
      'players': [
        {
          'player_id': 1001,
          'player_name': 'Contract Player',
          'player_image': 'https://example.com/player.png',
          'jersey_number': 10,
          'start_date': '2025-07-01',
          'end_date': '2028-06-30',
        },
      ],
    };
