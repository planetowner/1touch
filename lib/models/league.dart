// SQL table: leagues
// league_id | name | image_path
const Map<int, String> leagueNames = {
  8: "Premier League",
  82: "La Liga",
  301: "Serie A",
  384: "Bundesliga",
  564: "Ligue 1",
};

class League {
  final int leagueId;
  final String name;
  final String? imagePath;

  const League({
    required this.leagueId,
    required this.name,
    this.imagePath,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      leagueId:  json['league_id'] as int,
      name:      json['name'] as String,
      imagePath: json['image_path'] as String?,
    );
  }
}