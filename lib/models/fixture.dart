// SQL table: fixtures
// fixture_id | season_id | league_id | home_team_id | away_team_id
// competition_type (enum: league / europe / domestic_cup)
// round_name | stage_type_id | stage_id | group_id | leg_number
// status (enum: past / live / upcoming)
// starting_at | home_score | away_score | home_penalty_score | away_penalty_score

enum CompetitionType { league, europe, cup }

enum FixtureStatus { past, live, upcoming }

class Fixture {
  final int fixtureId;
  final int seasonId;
  final int leagueId;
  final int homeTeamId;
  final int awayTeamId;
  final CompetitionType competitionType;
  final String roundName;
  final int? stageTypeId;
  final int? stageId;
  final int? groupId;
  final int? legNumber; // 1 or 2 only (SQL CHECK constraint)
  final FixtureStatus status;
  final String startingAt; // datetime string: 'YYYY-MM-DD HH:MM:SS'
  final int? homeScore;
  final int? awayScore;
  final int? homePenaltyScore;
  final int? awayPenaltyScore;

  const Fixture({
    required this.fixtureId,
    required this.seasonId,
    required this.leagueId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.competitionType,
    required this.roundName,
    this.stageTypeId,
    this.stageId,
    this.groupId,
    this.legNumber,
    required this.status,
    required this.startingAt,
    this.homeScore,
    this.awayScore,
    this.homePenaltyScore,
    this.awayPenaltyScore,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) {
    return Fixture(
      fixtureId:       json['fixture_id'] as int,
      seasonId:        json['season_id'] as int,
      leagueId:        json['league_id'] as int,
      homeTeamId:      json['home_team_id'] as int,
      awayTeamId:      json['away_team_id'] as int,
      competitionType: _parseCompetitionType(json['competition_type'] as String),
      roundName:       json['round_name'] as String,
      stageTypeId:     json['stage_type_id'] as int?,
      stageId:         json['stage_id'] as int?,
      groupId:         json['group_id'] as int?,
      legNumber:       json['leg_number'] as int?,
      status:          _parseStatus(json['status'] as String),
      startingAt:      json['starting_at'] as String,
      homeScore:       json['home_score'] as int?,
      awayScore:       json['away_score'] as int?,
      homePenaltyScore: json['home_penalty_score'] as int?,
      awayPenaltyScore: json['away_penalty_score'] as int?,
    );
  }

  static CompetitionType _parseCompetitionType(String raw) {
    switch (raw) {
      case 'europe':       return CompetitionType.europe;
      case 'domestic_cup': return CompetitionType.cup;
      default:             return CompetitionType.league;
    }
  }

  static FixtureStatus _parseStatus(String raw) {
    switch (raw) {
      case 'live':     return FixtureStatus.live;
      case 'upcoming': return FixtureStatus.upcoming;
      default:         return FixtureStatus.past;
    }
  }
}