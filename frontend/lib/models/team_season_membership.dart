// 대회 ID는 team_seasons의 season_id로 seasons를 조회해 전달받아요.
class TeamSeasonMembership {
  const TeamSeasonMembership({
    required this.teamId,
    required this.seasonId,
    required this.competitionId,
  });

  final int teamId;
  final int seasonId;
  final int competitionId;

  factory TeamSeasonMembership.fromJson(Map<String, dynamic> json) =>
      TeamSeasonMembership(
        teamId: json['team_id'] as int,
        seasonId: json['season_id'] as int,
        competitionId: json['competition_id'] as int,
      );
}
