import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/standings/api/api_standing_response.dart';

void main() {
  test('parses the verified regular standings response', () {
    final response = ApiCompetitionStandingsResponse.fromJson(_responseJson());

    expect(response.competitionId, 8);
    expect(response.seasonId, 25583);
    expect(response.rows.single.teamId, 9);
    expect(response.rows.single.teamName, 'Manchester City');
    expect(response.rows.single.rankDelta, isNull);
    expect(response.rows.single.teamLogo, isNull);
    expect(response.rows.single.lastFiveForm, ['W', 'D']);
    expect(() => response.rows.clear(), throwsUnsupportedError);
    expect(
      () => response.rows.single.lastFiveForm.clear(),
      throwsUnsupportedError,
    );
  });

  test('requires the response envelope and row fields', () {
    for (final field in ['competition_id', 'season_id', 'rows']) {
      final json = _responseJson()..remove(field);
      expect(
        () => ApiCompetitionStandingsResponse.fromJson(json),
        throwsFormatException,
        reason: field,
      );
    }
    for (final field in _rowJson().keys) {
      final row = _rowJson()..remove(field);
      expect(
        () => ApiCompetitionStandingsResponse.fromJson({
          ..._responseJson(),
          'rows': [row],
        }),
        throwsFormatException,
        reason: field,
      );
    }
  });

  test('rejects malformed rows and invalid last-five values', () {
    for (final rows in [
      ['invalid'],
      [
        <String, dynamic>{..._rowJson(), 'position': '1'}
      ],
      [
        <String, dynamic>{..._rowJson(), 'team_name': null}
      ],
      [
        <String, dynamic>{..._rowJson(), 'rank_delta': 'up'}
      ],
      [
        <String, dynamic>{
          ..._rowJson(),
          'last5_form': ['W', 'X']
        }
      ],
      [
        <String, dynamic>{
          ..._rowJson(),
          'last5_form': ['W', 'W', 'W', 'W', 'W', 'W']
        }
      ],
    ]) {
      expect(
        () => ApiCompetitionStandingsResponse.fromJson({
          ..._responseJson(),
          'rows': rows,
        }),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _responseJson() => {
      'competition_id': 8,
      'season_id': 25583,
      'rows': [_rowJson()],
    };

Map<String, dynamic> _rowJson() => {
      'position': 1,
      'rank_delta': null,
      'team_id': 9,
      'team_name': 'Manchester City',
      'team_logo': null,
      'matches_played': 3,
      'won': 2,
      'draw': 1,
      'lost': 0,
      'goals_for': 8,
      'goals_against': 2,
      'goal_diff': 6,
      'points': 7,
      'last5_form': ['W', 'D'],
    };
