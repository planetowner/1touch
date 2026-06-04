// SQL table: standings
// league_id | season_id | phase (enum: league / group / league_phase)
// group_name | team_id | position | matches_played | won | draw | lost
// goals_for | goals_against | goal_diff | points | last5_form (json array)

enum StandingPhase { league, group, leaguePhase }

class Standing {
  final int leagueId;
  final int seasonId;
  final StandingPhase phase;
  final String groupName; // empty string when phase == league
  final int teamId;
  final int position;
  final int matchesPlayed;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final List<String> last5Form; // e.g. ['W','W','D','L','W']

  const Standing({
    required this.leagueId,
    required this.seasonId,
    required this.phase,
    required this.groupName,
    required this.teamId,
    required this.position,
    required this.matchesPlayed,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required this.last5Form,
  });

  factory Standing.fromJson(Map<String, dynamic> json) {
    return Standing(
      leagueId:      json['league_id'] as int,
      seasonId:      json['season_id'] as int,
      phase:         _parsePhase(json['phase'] as String),
      groupName:     json['group_name'] as String? ?? '',
      teamId:        json['team_id'] as int,
      position:      json['position'] as int,
      matchesPlayed: json['matches_played'] as int,
      won:           json['won'] as int,
      draw:          json['draw'] as int,
      lost:          json['lost'] as int,
      goalsFor:      json['goals_for'] as int,
      goalsAgainst:  json['goals_against'] as int,
      goalDiff:      json['goal_diff'] as int,
      points:        json['points'] as int,
      last5Form:     (json['last5_form'] as List<dynamic>).cast<String>(),
    );
  }

  static StandingPhase _parsePhase(String raw) {
    switch (raw) {
      case 'group':        return StandingPhase.group;
      case 'league_phase': return StandingPhase.leaguePhase;
      default:             return StandingPhase.league;
    }
  }
}

// SQL table: xg_standings (Big 5 leagues only)
// league_id | season_id | team_id | position
// matches_played | won | draw | lost
// xg (Decimal 3dp) | xga (Decimal 3dp) | xpts (Decimal 2dp)
//
// Important — these differ from regular standings:
//   - won/draw/lost are based on xG comparison per match, NOT actual result
//   - xpts uses 1Touch rule: team_xg > opp_xg → 3, == → 1, < → 0
//     (so xpts is NOT Understat's "expected points")
//   - Sort order: xpts DESC, (xg - xga) DESC, xg DESC, team_id ASC

class XgStanding {
  final int leagueId;
  final int seasonId;
  final int teamId;
  final int position;
  final int matchesPlayed;
  final int won;
  final int draw;
  final int lost;
  final double xg;
  final double xga;
  final double xpts;

  const XgStanding({
    required this.leagueId,
    required this.seasonId,
    required this.teamId,
    required this.position,
    required this.matchesPlayed,
    required this.won,
    required this.draw,
    required this.lost,
    required this.xg,
    required this.xga,
    required this.xpts,
  });

  factory XgStanding.fromJson(Map<String, dynamic> json) {
    return XgStanding(
      leagueId:      json['league_id'] as int,
      seasonId:      json['season_id'] as int,
      teamId:        json['team_id'] as int,
      position:      json['position'] as int,
      matchesPlayed: json['matches_played'] as int,
      won:           json['won'] as int,
      draw:          json['draw'] as int,
      lost:          json['lost'] as int,
      xg:            (json['xg']   as num).toDouble(),
      xga:           (json['xga']  as num).toDouble(),
      xpts:          (json['xpts'] as num).toDouble(),
    );
  }
}