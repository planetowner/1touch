import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/api/api_following_players_response.dart';

void main() {
  test('parses the ordered following-player response', () {
    final response = ApiFollowingPlayersResponse.fromJson({
      'items': [
        {
          'player_id': 268,
          'name': 'First Player',
          'image_path': 'https://cdn.example.com/268.png',
          'jersey_number': 7,
        },
        {
          'player_id': 832,
          'name': 'Second Player',
          'image_path': null,
          'jersey_number': null,
        },
      ],
    });

    expect(response.items.map((item) => item.playerId), [268, 832]);
    expect(response.items.first.name, 'First Player');
    expect(response.items.last.imagePath, isNull);
    expect(response.items.first.jerseyNumber, 7);
    expect(response.items.last.jerseyNumber, isNull);
    expect(() => response.items.clear(), throwsUnsupportedError);
  });

  test('accepts old cached players without jersey numbers', () {
    final response = ApiFollowingPlayerResponse.fromJson({
      'player_id': 268,
      'name': 'First Player',
      'image_path': null,
    });
    expect(response.jerseyNumber, isNull);
  });

  test('rejects malformed jersey numbers', () {
    for (final number in ['7', 7.5, true]) {
      expect(
        () => ApiFollowingPlayerResponse.fromJson({
          'player_id': 268,
          'name': 'First Player',
          'image_path': null,
          'jersey_number': number,
        }),
        throwsFormatException,
      );
    }
  });

  test('requires image_path to be present even when its value is null', () {
    expect(
      () => ApiFollowingPlayersResponse.fromJson({
        'items': [
          {'player_id': 268, 'name': 'First Player'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects malformed following-player fields and collection shapes', () {
    expect(
      () => ApiFollowingPlayersResponse.fromJson({'items': {}}),
      throwsFormatException,
    );
    expect(
      () => ApiFollowingPlayersResponse.fromJson({
        'items': [
          {'player_id': '268', 'name': 'First Player', 'image_path': null},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => ApiFollowingPlayersResponse.fromJson({
        'items': [
          {'player_id': 268, 'name': null, 'image_path': null},
        ],
      }),
      throwsFormatException,
    );
  });

  test('parses and validates the following-player update response', () {
    expect(
      ApiFollowingPlayersUpdateResponse.fromJson({'ok': true}).ok,
      isTrue,
    );
    expect(
      () => ApiFollowingPlayersUpdateResponse.fromJson({'ok': 'true'}),
      throwsFormatException,
    );
  });
}
