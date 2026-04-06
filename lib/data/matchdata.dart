import 'miniteam.dart';

class MatchData {
  final int id;
  final int leagueId;
  final int seasonId;

  // Kept from original — nullable since API uses roundName instead
  final int? roundId;
  final int? venueId;

  final int homeId;
  final int awayId;
  final String date;
  final String status;

  // ── Competition metadata (from FixtureOut) ──
  final String? competitionType;
  final String? roundName;
  final int? stageId;
  final int? groupId;
  final int? legNumber;

  // ── Scores (from FixtureOut) ──
  final int? homeScore;
  final int? awayScore;
  final int? homePenaltyScore;
  final int? awayPenaltyScore;

  // ── Team objects ──
  // Built from nested JSON object OR flat name/logo fields from FixtureOut
  final MiniTeam? homeTeam;
  final MiniTeam? awayTeam;

  MatchData({
    required this.id,
    required this.leagueId,
    required this.seasonId,
    this.roundId,
    this.venueId,
    required this.homeId,
    required this.awayId,
    required this.date,
    required this.status,
    this.competitionType,
    this.roundName,
    this.stageId,
    this.groupId,
    this.legNumber,
    this.homeScore,
    this.awayScore,
    this.homePenaltyScore,
    this.awayPenaltyScore,
    this.homeTeam,
    this.awayTeam,
  });

  factory MatchData.fromJson(Map<String, dynamic> json) {
    // Build MiniTeam from nested object if present,
    // otherwise fall back to flat fields from FixtureOut shape.
    MiniTeam? homeTeam;
    if (json['home_team'] != null) {
      homeTeam = MiniTeam.fromJson(json['home_team']);
    } else if (json['home_team_name'] != null) {
      homeTeam = MiniTeam(
        id: json['home_team_id'] as int,
        name: json['home_team_name'] as String,
        shortCode: '',
        imagePath: json['home_team_logo'] as String? ?? '',
      );
    }

    MiniTeam? awayTeam;
    if (json['away_team'] != null) {
      awayTeam = MiniTeam.fromJson(json['away_team']);
    } else if (json['away_team_name'] != null) {
      awayTeam = MiniTeam(
        id: json['away_team_id'] as int,
        name: json['away_team_name'] as String,
        shortCode: '',
        imagePath: json['away_team_logo'] as String? ?? '',
      );
    }

    return MatchData(
      id: json['fixture_id'] ?? json['id'],
      leagueId: json['league_id'],
      seasonId: json['season_id'],
      roundId: json['round_id'] as int?,
      venueId: json['venue_id'] as int?,
      homeId: json['home_team_id'],
      awayId: json['away_team_id'],
      date: json['starting_at'] ?? '',
      status: json['status'] ?? '',
      competitionType: json['competition_type'] as String?,
      roundName: json['round_name'] as String?,
      stageId: json['stage_id'] as int?,
      groupId: json['group_id'] as int?,
      legNumber: json['leg_number'] as int?,
      homeScore: json['home_score'] as int?,
      awayScore: json['away_score'] as int?,
      homePenaltyScore: json['home_penalty_score'] as int?,
      awayPenaltyScore: json['away_penalty_score'] as int?,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
    );
  }
}

class Substitute {
  final String name;
  final int? minute;
  final bool goal;
  final bool subIn;

  Substitute({
    required this.name,
    this.minute,
    this.goal = false,
    this.subIn = false,
  });
}