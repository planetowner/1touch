// SQL table: seasons
// season_id | league_id | name | is_current | starting_at | ending_at

class Season {
  final int seasonId;
  final int leagueId;
  final String name;
  final bool isCurrent;
  final String startingAt; // datetime string: 'YYYY-MM-DD HH:MM:SS'
  final String endingAt;

  const Season({
    required this.seasonId,
    required this.leagueId,
    required this.name,
    required this.isCurrent,
    required this.startingAt,
    required this.endingAt,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonId:   json['season_id'] as int,
      leagueId:   json['league_id'] as int,
      name:       json['name'] as String,
      isCurrent:  (json['is_current'] as int) == 1,
      startingAt: json['starting_at'] as String,
      endingAt:   json['ending_at'] as String,
    );
  }
}