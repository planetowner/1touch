import 'miniteam.dart';

class MatchData {
  final int id;
  final int leagueId;
  final int seasonId;
  final int roundId;
  final int venueId;
  final int homeId;
  final int awayId;
  final String date;
  final String status;
  final MiniTeam? homeTeam;
  final MiniTeam? awayTeam;

  MatchData({
    required this.id,
    required this.leagueId,
    required this.seasonId,
    required this.roundId,
    required this.venueId,
    required this.homeId,
    required this.awayId,
    required this.date,
    required this.status,
    this.homeTeam,
    this.awayTeam,
  });

  factory MatchData.fromJson(Map<String, dynamic> json) {
    return MatchData(
      id: json['id'],
      leagueId: json['league_id'],
      seasonId: json['season_id'],
      roundId: json['round_id'],
      venueId: json['venue_id'],
      homeId: json['home_team_id'],
      awayId: json['away_team_id'],
      date: json['starting_at'],
      status: json['status'],
      homeTeam: json['home_team'] != null
          ? MiniTeam.fromJson(json['home_team'])
          : null,
      awayTeam: json['away_team'] != null
          ? MiniTeam.fromJson(json['away_team'])
          : null,
    );
  }
}


class Substitute {
  final String name;
  final int? minute; // null if no minute
  final bool goal;
  final bool subIn;

  Substitute({
    required this.name,
    this.minute,
    this.goal = false,
    this.subIn = false,
  });
}