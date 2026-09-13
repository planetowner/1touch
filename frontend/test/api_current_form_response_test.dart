import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/current_form/api/api_current_form_response.dart';

void main() {
  test('parses the verified Current Form options response', () {
    final response = ApiCurrentFormOptionsResponse.fromJson({
      'items': [_optionJson()],
      'limit': 200,
    });

    expect(response.limit, 200);
    expect(response.items.single.teamId, 83);
    expect(response.items.single.competitionId, 564);
    expect(response.items.single.seasonId, 25659);
  });

  test('parses documented nullable option display fields', () {
    final response = ApiCurrentFormOptionsResponse.fromJson({
      'items': [
        {
          ..._optionJson(),
          'team_name': null,
          'team_short_code': null,
          'team_logo': null,
        },
      ],
      'limit': 1,
    });

    expect(response.items.single.teamName, isNull);
    expect(response.items.single.teamShortCode, isNull);
    expect(response.items.single.teamLogo, isNull);
  });

  test('parses the verified Current Form comparison response', () {
    final response = ApiCurrentFormResponse.fromJson(_comparisonJson());

    expect(response.current.teamId, 83);
    expect(response.current.competitionId, 564);
    expect(response.current.points.first.roundNo, 0);
    expect(response.current.points.first.matchDate, isNull);
    expect(response.comparison.seasonId, 23621);
    expect(response.maxRound, 2);
    expect(response.maxPoints, 4);
  });

  test('rejects old field names and malformed nested values', () {
    final oldOption = {
      ..._optionJson(),
      'league_id': 564,
    }..remove('competition_id');
    final malformedComparison = _comparisonJson();
    (malformedComparison['current'] as Map<String, dynamic>)['points'] = [1];

    expect(
      () => ApiCurrentFormOptionsResponse.fromJson({
        'items': [oldOption],
        'limit': 200,
      }),
      throwsFormatException,
    );
    expect(
      () => ApiCurrentFormResponse.fromJson(malformedComparison),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _optionJson() => {
      'team_id': 83,
      'team_name': 'FC Barcelona',
      'team_short_code': 'BAR',
      'team_logo': 'https://example.com/barcelona.png',
      'competition_id': 564,
      'season_id': 25659,
      'season_name': '2025/2026',
      'rounds_available': 2,
      'latest_round': 2,
    };

Map<String, dynamic> _comparisonJson() => {
      'current': _seriesJson(
        teamId: 83,
        seasonId: 25659,
        seasonName: '2025/2026',
        isCurrent: true,
      ),
      'comparison': _seriesJson(
        teamId: 83,
        seasonId: 23621,
        seasonName: '2024/2025',
        isCurrent: false,
      ),
      'max_round': 2,
      'max_points': 4,
    };

Map<String, dynamic> _seriesJson({
  required int teamId,
  required int seasonId,
  required String seasonName,
  required bool isCurrent,
}) =>
    {
      'team_id': teamId,
      'team_name': 'FC Barcelona',
      'team_short_code': 'BAR',
      'team_logo': 'https://example.com/barcelona.png',
      'competition_id': 564,
      'season_id': seasonId,
      'season_name': seasonName,
      'is_current': isCurrent,
      'points': [
        {
          'round_no': 0,
          'match_date': null,
          'cumulative_points': 0,
        },
        {
          'round_no': 2,
          'match_date': '2025-08-16T19:00:00',
          'cumulative_points': 4,
        },
      ],
    };
