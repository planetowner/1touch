import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_response.dart';

void main() {
  test('parses the verified Team overview response', () {
    final response = ApiTeamOverviewResponse.fromJson(_overviewJson());

    expect(response.team.teamId, 83);
    expect(response.nextMatch?.fixtureId, 1001);
    expect(response.lastMatch?.fixtureId, 1000);
    expect(response.standing?.position, 1);
    expect(response.standing?.rankDelta, isNull);
    expect(response.standing?.lastFiveForm, ['W', 'D']);
    expect(
      () => response.standing!.lastFiveForm.clear(),
      throwsUnsupportedError,
    );
  });

  test('preserves nullable overview aggregates and team metadata', () {
    final response = ApiTeamOverviewResponse.fromJson({
      ..._overviewJson(),
      'team': {
        'team_id': 83,
        'name': 'FC Barcelona',
        'short_code': null,
        'image_path': null,
      },
      'next_match': null,
      'last_match': null,
      'standing': null,
    });

    expect(response.team.shortCode, isNull);
    expect(response.team.imagePath, isNull);
    expect(response.nextMatch, isNull);
    expect(response.lastMatch, isNull);
    expect(response.standing, isNull);
  });

  test('requires all top-level keys with their documented shapes', () {
    for (final field in ['team', 'next_match', 'last_match', 'standing']) {
      final missing = _overviewJson()..remove(field);
      expect(
        () => ApiTeamOverviewResponse.fromJson(missing),
        throwsFormatException,
        reason: field,
      );
    }
  });

  test('rejects malformed standing fields and form entries', () {
    for (final standing in [
      {..._standingJson(), 'position': '1'},
      {..._standingJson(), 'rank_delta': 'up'},
      {..._standingJson(), 'team_name': null},
      {
        ..._standingJson(),
        'last5_form': ['W', 1]
      },
    ]) {
      expect(
        () => ApiTeamOverviewResponse.fromJson({
          ..._overviewJson(),
          'standing': standing,
        }),
        throwsFormatException,
      );
    }
  });

  test('requires nullable standing fields to be present or null', () {
    for (final field in ['rank_delta', 'team_logo']) {
      final standing = _standingJson()..remove(field);
      expect(
        () => ApiTeamOverviewResponse.fromJson({
          ..._overviewJson(),
          'standing': standing,
        }),
        throwsFormatException,
        reason: field,
      );
    }
  });
}

Map<String, dynamic> _overviewJson() => {
      'team': {
        'team_id': 83,
        'name': 'FC Barcelona',
        'short_code': 'BAR',
        'image_path': 'https://cdn.example/83.png',
      },
      'next_match': _fixtureJson(1001, 'upcoming'),
      'last_match': _fixtureJson(1000, 'past'),
      'standing': _standingJson(),
    };

Map<String, dynamic> _standingJson() => {
      'position': 1,
      'rank_delta': null,
      'team_id': 83,
      'team_name': 'FC Barcelona',
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

Map<String, dynamic> _fixtureJson(int id, String status) => {
      'fixture_id': id,
      'competition_id': 564,
      'season_id': 25659,
      'competition_type': 'league',
      'round_name': '3',
      'stage_id': 1,
      'stage_name': 'Regular Season',
      'round_id': 3,
      'group_id': null,
      'aggregate_id': null,
      'leg': 'single',
      'venue_id': null,
      'state_id': status == 'past' ? 5 : 1,
      'state_code': status == 'past' ? 'FT' : 'NS',
      'state_name': status == 'past' ? 'Finished' : 'Not Started',
      'status': status,
      'starting_at': '2026-09-20 15:00:00',
      'home_team_id': 83,
      'away_team_id': 3468,
      'home_score': status == 'past' ? 2 : null,
      'away_score': status == 'past' ? 1 : null,
      'home_penalty_score': null,
      'away_penalty_score': null,
      'home_team_name': 'FC Barcelona',
      'away_team_name': 'Girona',
      'home_team_logo': null,
      'away_team_logo': null,
    };
