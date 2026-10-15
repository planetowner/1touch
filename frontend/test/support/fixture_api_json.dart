Map<String, dynamic> fixtureApiJson({
  int fixtureId = 19712345,
  String startingAt = '2026-08-29 14:00:00',
}) {
  return {
    'fixture_id': fixtureId,
    'competition_id': 8,
    'season_id': 25583,
    'competition_type': 'league',
    'round_name': '3',
    'stage_id': 77432101,
    'stage_name': 'Regular Season',
    'round_id': 375001,
    'group_id': null,
    'aggregate_id': null,
    'leg': '1/1',
    'venue_id': 206,
    'state_id': 1,
    'state_code': 'NS',
    'state_name': 'Not Started',
    'status': 'upcoming',
    'starting_at': startingAt,
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': null,
    'away_score': null,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/liverpool.png',
    'away_team_logo': null,
  };
}

Map<String, dynamic> fixtureDetailApiJson({int fixtureId = 19712345}) {
  return {
    ...fixtureApiJson(fixtureId: fixtureId),
    'venue_name': 'Anfield',
    'expected_goals': {
      'home_xg': 1.75,
      'away_xg': 0.82,
      'home_xga': 0.82,
      'away_xga': 1.75,
      'provider': 'understat',
    },
    'player_expected_goals': [],
    'shots': [],
    'events': [],
    'statistics': [],
    'player_statistics': [],
    'lineups': [],
    'formations': [],
    'coaches': [],
    'pressure': [
      {
        'team_id': 8,
        'minute': 27,
        'pressure': 0.78,
      },
    ],
  };
}
