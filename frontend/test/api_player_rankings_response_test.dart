import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/api/api_player_rankings_response.dart';

void main() {
  test('parses the verified player-rankings response shape', () {
    final response = ApiPlayerRankingsResponse.fromJson(_rankingsJson());

    expect(response.competitionId, 8);
    expect(response.seasonId, 28083);
    expect(response.reference.minimumRatedMatches, 10);
    expect(response.items.first.playerName, 'Player One');
    expect(response.items.first.playerImage, isNull);
    expect(response.items.first.averageRating, 7.25);
    expect(() => response.items.clear(), throwsUnsupportedError);
  });

  test('requires the nullable player_image key', () {
    final json = _rankingsJson();
    ((json['items'] as List).first as Map<String, dynamic>)
        .remove('player_image');

    expect(
      () => ApiPlayerRankingsResponse.fromJson(json),
      throwsFormatException,
    );
  });

  test('rejects a non-numeric ranking score', () {
    final json = _rankingsJson();
    ((json['items'] as List).first as Map<String, dynamic>)['display_score'] =
        '98.4';

    expect(
      () => ApiPlayerRankingsResponse.fromJson(json),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _rankingsJson() => {
      'competition_id': 8,
      'season_id': 28083,
      'season_name': '2026/2027',
      'method': 'fixed_historical_percentile',
      'reference': {
        'start_season_name': '2020/2021',
        'end_season_name': '2024/2025',
        'minimum_rated_matches': 10,
        'sample_count': 900,
        'frozen_at': '2026-09-01T12:00:00Z',
      },
      'total': 1,
      'limit': 20,
      'offset': 0,
      'items': [
        {
          'rank': 1,
          'player_id': 101,
          'player_name': 'Player One',
          'player_image': null,
          'rated_matches': 12,
          'average_rating': 7.25,
          'percentile_score': 98.37,
          'display_score': 9.8,
          'updated_at': '2026-09-18T20:00:00+00:00',
        },
      ],
    };
