import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_response.dart';

void main() {
  test('parses the verified xG standings response', () {
    final response =
        ApiCompetitionXgStandingsResponse.fromJson(_responseJson());

    expect(response.competitionId, 8);
    expect(response.seasonId, 25583);
    expect(response.provider, 'understat');
    expect(response.xptsMethod, 'historical_draw_rate');
    expect(response.rows.single.teamId, 9);
    expect(response.rows.single.teamName, 'Manchester City');
    expect(response.rows.single.teamLogo, isNull);
    expect(response.rows.single.xg, 8.125);
    expect(response.rows.single.xga, 2.5);
    expect(response.rows.single.xpts, 7.25);
    expect(() => response.rows.clear(), throwsUnsupportedError);
  });

  test('requires the response envelope and row fields', () {
    for (final field in [
      'competition_id',
      'season_id',
      'provider',
      'xpts_method',
      'rows',
    ]) {
      final json = _responseJson()..remove(field);
      expect(
        () => ApiCompetitionXgStandingsResponse.fromJson(json),
        throwsFormatException,
        reason: field,
      );
    }
    for (final field in _rowJson().keys) {
      final row = _rowJson()..remove(field);
      expect(
        () => ApiCompetitionXgStandingsResponse.fromJson({
          ..._responseJson(),
          'rows': [row],
        }),
        throwsFormatException,
        reason: field,
      );
    }
  });

  test('rejects malformed rows and required values', () {
    for (final json in [
      <String, dynamic>{
        ..._responseJson(),
        'rows': ['invalid']
      },
      <String, dynamic>{..._responseJson(), 'provider': null},
      <String, dynamic>{
        ..._responseJson(),
        'rows': [
          <String, dynamic>{..._rowJson(), 'team_name': null}
        ],
      },
      <String, dynamic>{
        ..._responseJson(),
        'rows': [
          <String, dynamic>{..._rowJson(), 'xg': '8.125'}
        ],
      },
    ]) {
      expect(
        () => ApiCompetitionXgStandingsResponse.fromJson(json),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _responseJson({
  int competitionId = 8,
  int seasonId = 25583,
}) =>
    {
      'competition_id': competitionId,
      'season_id': seasonId,
      'provider': 'understat',
      'xpts_method': 'historical_draw_rate',
      'rows': [_rowJson()],
    };

Map<String, dynamic> _rowJson() => {
      'position': 1,
      'team_id': 9,
      'team_name': 'Manchester City',
      'team_logo': null,
      'matches_played': 3,
      'xg': 8.125,
      'xga': 2.5,
      'xpts': 7.25,
    };
