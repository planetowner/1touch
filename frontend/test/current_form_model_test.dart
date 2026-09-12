import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/current_form.dart';

void main() {
  test('parses the backend current-form response contract', () {
    final comparison = CurrentFormComparison.fromJson({
      'current': _seriesJson(
        teamId: 83,
        teamName: 'Barcelona',
        seasonId: 25659,
        seasonName: '2025/2026',
        isCurrent: true,
      ),
      'comparison': _seriesJson(
        teamId: 3468,
        teamName: 'Real Madrid',
        seasonId: 23621,
        seasonName: '2024/2025',
        isCurrent: false,
      ),
      'max_round': 2,
      'max_points': 4,
    });

    expect(comparison.current.teamLogo, 'team-83.png');
    expect(comparison.current.seasonStart, DateTime(2025, 8, 1));
    expect(comparison.current.seasonEnd, DateTime(2026, 5, 31));
    expect(comparison.current.points.first.roundNo, 0);
    expect(comparison.current.points.last.cumulativePoints, 4);
    expect(comparison.comparison.teamName, 'Real Madrid');
    expect(comparison.maxRound, 2);
    expect(comparison.maxPoints, 4);
  });

  test('parses the backend current-form option contract', () {
    final option = CurrentFormOption.fromJson({
      'team_id': 83,
      'team_name': 'Barcelona',
      'team_short_code': 'BAR',
      'team_logo': 'team-83.png',
      'league_id': 564,
      'season_id': 25659,
      'season_name': '2025/2026',
      'season_starting_at': '2025-08-01',
      'season_ending_at': '2026-05-31',
      'rounds_available': 38,
      'latest_round': 38,
    });

    expect(option.teamLogo, 'team-83.png');
    expect(option.leagueId, 564);
    expect(option.seasonId, 25659);
    expect(option.roundsAvailable, 38);
    expect(option.latestRound, 38);
  });
}

Map<String, dynamic> _seriesJson({
  required int teamId,
  required String teamName,
  required int seasonId,
  required String seasonName,
  required bool isCurrent,
}) {
  return {
    'team_id': teamId,
    'team_name': teamName,
    'team_short_code': teamName.substring(0, 3).toUpperCase(),
    'team_logo': 'team-$teamId.png',
    'league_id': 564,
    'season_id': seasonId,
    'season_name': seasonName,
    'season_starting_at': '2025-08-01',
    'season_ending_at': '2026-05-31',
    'is_current': isCurrent,
    'points': [
      {
        'round_no': 2,
        'match_date': '2025-08-16',
        'cumulative_points': 4,
      },
      {
        'round_no': 0,
        'match_date': null,
        'cumulative_points': 0,
      },
    ],
  };
}
