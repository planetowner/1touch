// SQL table: standings
// competition_id | season_id | phase (enum: league / group / league_phase)
// group_name | team_id | position | matches_played | won | draw | lost
// goals_for | goals_against | goal_diff | points | last5_form (json array)

enum StandingPhase { league, group, leaguePhase }

class Standing {
  final int competitionId;
  final int seasonId;
  final StandingPhase phase;
  final String groupName; // empty string when phase == league
  final int teamId;
  final String? teamName;
  final String? teamLogo;
  final int position;
  final int? rankDelta;
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
    required this.competitionId,
    required this.seasonId,
    required this.phase,
    required this.groupName,
    required this.teamId,
    this.teamName,
    this.teamLogo,
    required this.position,
    this.rankDelta,
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
      competitionId: json['competition_id'] as int,
      seasonId: json['season_id'] as int,
      phase: _parsePhase(json['phase'] as String),
      groupName: json['group_name'] as String? ?? '',
      teamId: json['team_id'] as int,
      teamName: json['team_name'] as String?,
      teamLogo: json['team_logo'] as String?,
      position: json['position'] as int,
      rankDelta: json['rank_delta'] as int?,
      matchesPlayed: json['matches_played'] as int,
      won: json['won'] as int,
      draw: json['draw'] as int,
      lost: json['lost'] as int,
      goalsFor: json['goals_for'] as int,
      goalsAgainst: json['goals_against'] as int,
      goalDiff: json['goal_diff'] as int,
      points: json['points'] as int,
      last5Form: (json['last5_form'] as List<dynamic>).cast<String>(),
    );
  }

  static StandingPhase _parsePhase(String raw) {
    switch (raw) {
      case 'group':
        return StandingPhase.group;
      case 'league_phase':
        return StandingPhase.leaguePhase;
      default:
        return StandingPhase.league;
    }
  }
}

// API domain for xg_standings (Big 5 leagues only)
// competition_id is derived through the season relationship in the backend.
// competition_id | season_id | team_id | position
// matches_played
// xg (Decimal 3dp) | xga (Decimal 3dp) | xpts (Decimal 2dp)
//
// The real API does not expose xG-derived W/D/L. Those fields remain optional
// only so the existing mock catalog can be migrated without a bulk rewrite.
// The response's xpts_method explains how xPts was calculated.
//   - Sort order: xpts DESC, (xg - xga) DESC, xg DESC, team_id ASC

class XgStanding {
  final int competitionId;
  final int seasonId;
  final int teamId;
  final String? teamName;
  final String? teamLogo;
  final int position;
  final int matchesPlayed;
  final int? won;
  final int? draw;
  final int? lost;
  final double xg;
  final double xga;
  final double xpts;
  final String? provider;
  final String? xptsMethod;

  const XgStanding({
    required this.competitionId,
    required this.seasonId,
    required this.teamId,
    this.teamName,
    this.teamLogo,
    required this.position,
    required this.matchesPlayed,
    this.won,
    this.draw,
    this.lost,
    required this.xg,
    required this.xga,
    required this.xpts,
    this.provider,
    this.xptsMethod,
  });

  factory XgStanding.fromJson(Map<String, dynamic> json) {
    return XgStanding(
      competitionId: json['competition_id'] as int,
      seasonId: json['season_id'] as int,
      teamId: json['team_id'] as int,
      teamName: json['team_name'] as String?,
      teamLogo: json['team_logo'] as String?,
      position: json['position'] as int,
      matchesPlayed: json['matches_played'] as int,
      won: json['won'] as int?,
      draw: json['draw'] as int?,
      lost: json['lost'] as int?,
      xg: (json['xg'] as num).toDouble(),
      xga: (json['xga'] as num).toDouble(),
      xpts: (json['xpts'] as num).toDouble(),
      provider: json['provider'] as String?,
      xptsMethod: json['xpts_method'] as String?,
    );
  }
}
