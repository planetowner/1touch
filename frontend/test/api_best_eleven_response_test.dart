import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_response.dart';

void main() {
  test('parses the verified best-eleven response', () {
    final response = ApiBestElevenResponse.fromJson(_responseJson());

    expect(response.teamId, 83);
    expect(response.seasonId, 25659);
    expect(response.formation, '4-3-3');
    expect(response.matchesUsed, 20);
    expect(response.totalValidMatches, 30);
    expect(response.usagePercentage, 66.67);
    expect(response.formations.single.isDefault, isTrue);
    expect(response.players.single.playerName, 'Player Name');
    expect(response.players.single.jerseyNumber, 4);
    expect(response.players.single.positionGroupCode, 'DEF');
    expect(response.players.single.positionCode, 'CB');
    expect(response.players.single.starts, 18);
    expect(() => response.players.clear(), throwsUnsupportedError);
  });

  test('accepts nullable player metadata', () {
    final json = _responseJson();
    final player = (json['players'] as List).single as Map<String, dynamic>;
    player
      ..['player_name'] = null
      ..['player_image'] = null
      ..['jersey_number'] = null
      ..['position_group_code'] = null
      ..['position_code'] = null;

    final result = ApiBestElevenResponse.fromJson(json).players.single;

    expect(result.playerName, isNull);
    expect(result.playerImage, isNull);
    expect(result.jerseyNumber, isNull);
    expect(result.positionGroupCode, isNull);
    expect(result.positionCode, isNull);
  });

  test('accepts integer usage percentages', () {
    final json = _responseJson()
      ..['usage_percentage'] = 67
      ..['formations'] = [
        {
          ...(jsonFormation),
          'usage_percentage': 67,
        },
      ];

    final response = ApiBestElevenResponse.fromJson(json);

    expect(response.usagePercentage, 67.0);
    expect(response.formations.single.usagePercentage, 67.0);
  });

  test('rejects missing required root fields', () {
    for (final field in _responseJson().keys) {
      final json = _responseJson()..remove(field);

      expect(
        () => ApiBestElevenResponse.fromJson(json),
        throwsFormatException,
        reason: 'missing $field should be rejected',
      );
    }
  });

  test('rejects malformed nested fields and list items', () {
    for (final json in [
      _responseJson()..['formations'] = '4-3-3',
      _responseJson()..['players'] = [1],
      _responseJson()
        ..['players'] = [
          {...jsonPlayer, 'starts': '18'},
        ],
      _responseJson()
        ..['players'] = [
          {...jsonPlayer, 'jersey_number': '4'},
        ],
      _responseJson()
        ..['formations'] = [
          {...jsonFormation, 'is_default': 1},
        ],
    ]) {
      expect(
        () => ApiBestElevenResponse.fromJson(json),
        throwsFormatException,
      );
    }
  });
}

const jsonFormation = <String, dynamic>{
  'formation': '4-3-3',
  'matches_used': 20,
  'total_valid_matches': 30,
  'usage_percentage': 66.67,
  'is_default': true,
};

const jsonPlayer = <String, dynamic>{
  'slot_key': '2:2',
  'slot_index': 3,
  'player_id': 100,
  'player_name': 'Player Name',
  'player_image': 'https://example.com/player.png',
  'jersey_number': 4,
  'position_group_code': 'DEF',
  'position_code': 'CB',
  'starts': 18,
};

Map<String, dynamic> _responseJson() {
  return {
    'team_id': 83,
    'season_id': 25659,
    'formation': '4-3-3',
    'matches_used': 20,
    'total_valid_matches': 30,
    'usage_percentage': 66.67,
    'formations': [
      {...jsonFormation}
    ],
    'players': [
      {...jsonPlayer}
    ],
  };
}
