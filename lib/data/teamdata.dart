import 'matchdata.dart';

const Map<int, String> leagueNames = {
  8: "Premier League",
  82: "La Liga",
  301: "Serie A",
  384: "Bundesliga",
  564: "Ligue 1",
};


class Team {
  final int id;
  final String name;
  final String shortName;
  final String imagePath;
  final int leagueId;
  final Map<String, dynamic>? standing;
  final MatchData? nextMatch;
  final MatchData? lastMatch;

  Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.imagePath,
    required this.leagueId,
    required this.standing,
    this.nextMatch,
    this.lastMatch
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      shortName: json['short_code'] ?? '',
      imagePath: json['image_path'] ?? '',
      leagueId: json['league_id'] ?? 0, // ✅ prevents Null→int crash
      standing: json['standing'] as Map<String, dynamic>?,
      nextMatch: json['nextMatch'] != null
          ? MatchData.fromJson(json['nextMatch'])
          : null,
      lastMatch: json['lastMatch'] != null
          ? MatchData.fromJson(json['lastMatch'])
          : null, // ✅ added
    );
  }
}