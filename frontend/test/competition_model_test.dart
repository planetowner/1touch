import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/match_data.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/standing.dart';

void main() {
  group('competition_id JSON contract', () {
    test('Competition parses competition_id', () {
      final competition = Competition.fromJson({
        'competition_id': 8,
        'name': 'Premier League',
        'image_path': null,
      });

      expect(competition.competitionId, 8);
      expect(competition.name, 'Premier League');
    });

    test('Fixture parses competition_id and keeps domestic cup mapping', () {
      final fixture = Fixture.fromJson({
        'fixture_id': 1,
        'season_id': 2,
        'competition_id': 24,
        'home_team_id': 3,
        'away_team_id': 4,
        'competition_type': 'domestic_cup',
        'round_name': 'Final',
        'status': 'upcoming',
        'starting_at': '2026-05-16 18:00:00',
      });

      expect(fixture.competitionId, 24);
      expect(fixture.competitionType, CompetitionType.cup);
    });

    test('Season parses competition_id', () {
      final season = Season.fromJson({
        'season_id': 2,
        'competition_id': 8,
        'name': '2025/2026',
        'is_current': 1,
        'starting_at': '2025-08-15 00:00:00',
        'ending_at': '2026-05-24 00:00:00',
      });

      expect(season.competitionId, 8);
      expect(season.isCurrent, isTrue);
    });

    test('Standing and XgStanding parse competition_id', () {
      final standing = Standing.fromJson({
        'competition_id': 8,
        'season_id': 2,
        'phase': 'league',
        'group_name': null,
        'team_id': 3,
        'position': 1,
        'matches_played': 10,
        'won': 7,
        'draw': 2,
        'lost': 1,
        'goals_for': 20,
        'goals_against': 8,
        'goal_diff': 12,
        'points': 23,
        'last5_form': ['W', 'W', 'D', 'W', 'L'],
      });
      final xgStanding = XgStanding.fromJson({
        'competition_id': 8,
        'season_id': 2,
        'team_id': 3,
        'position': 1,
        'matches_played': 10,
        'won': 6,
        'draw': 2,
        'lost': 2,
        'xg': 18.125,
        'xga': 9.5,
        'xpts': 20.25,
      });

      expect(standing.competitionId, 8);
      expect(standing.phase, StandingPhase.league);
      expect(xgStanding.competitionId, 8);
    });

    test('MatchData parses competition_id', () {
      final match = MatchData.fromJson({
        'fixture_id': 1,
        'competition_id': 5,
        'season_id': 2,
        'home_team_id': 3,
        'away_team_id': 4,
        'starting_at': '2026-05-20 18:00:00',
        'status': 'upcoming',
      });

      expect(match.competitionId, 5);
    });
  });
}
