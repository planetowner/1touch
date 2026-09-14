import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';

void main() {
  test('parses the verified team-injuries response', () {
    final response = ApiTeamInjuriesResponse.fromJson(_reportJson());

    expect(response.teamId, 83);
    expect(response.seasonId, 25659);
    expect(response.players.single.playerId, 1001);
    expect(response.players.single.injuries, hasLength(2));
    expect(response.players.single.injuries.first.typeName, 'Hamstring');
  });

  test('preserves every documented nullable injury field', () {
    final player = ApiTeamInjuriesResponse.fromJson({
      'team_id': 83,
      'season_id': 25659,
      'players': [
        {
          'player_id': 1001,
          'player_name': 'Injured Player',
          'player_image': null,
          'jersey_number': null,
          'injuries': [
            {
              'sideline_id': 5001,
              'type_id': 2,
              'type_name': 'Hamstring',
              'start_date': null,
              'end_date': null,
            },
          ],
        },
      ],
    }).players.single;

    expect(player.playerImage, isNull);
    expect(player.jerseyNumber, isNull);
    expect(player.injuries.single.startDate, isNull);
    expect(player.injuries.single.endDate, isNull);
  });

  test('rejects malformed required, nullable, and nested fields', () {
    final malformedName = _reportJson();
    final malformedNamePlayer = Map<String, dynamic>.from(
      (malformedName['players'] as List).single as Map,
    )..['player_name'] = null;
    malformedName['players'] = [malformedNamePlayer];

    final malformedJersey = _reportJson();
    final malformedJerseyPlayer = Map<String, dynamic>.from(
      (malformedJersey['players'] as List).single as Map,
    )..['jersey_number'] = '10';
    malformedJersey['players'] = [malformedJerseyPlayer];

    final malformedInjuries = _reportJson();
    final malformedInjuriesPlayer = Map<String, dynamic>.from(
      (malformedInjuries['players'] as List).single as Map,
    )..['injuries'] = [1];
    malformedInjuries['players'] = [malformedInjuriesPlayer];

    expect(
      () => ApiTeamInjuriesResponse.fromJson(malformedName),
      throwsFormatException,
    );
    expect(
      () => ApiTeamInjuriesResponse.fromJson(malformedJersey),
      throwsFormatException,
    );
    expect(
      () => ApiTeamInjuriesResponse.fromJson(malformedInjuries),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _reportJson() => {
      'team_id': 83,
      'season_id': 25659,
      'players': [
        {
          'player_id': 1001,
          'player_name': 'Injured Player',
          'player_image': 'https://example.com/player.png',
          'jersey_number': 10,
          'injuries': [
            {
              'sideline_id': 5001,
              'type_id': 2,
              'type_name': 'Hamstring',
              'start_date': '2026-08-01',
              'end_date': '2026-09-01',
            },
            {
              'sideline_id': 5002,
              'type_id': 3,
              'type_name': 'Knock',
              'start_date': '2026-08-15',
              'end_date': null,
            },
          ],
        },
      ],
    };
