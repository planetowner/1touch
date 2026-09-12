// Backend table: team_seasons
// team_id | season_id | league_id
class TeamSeasonMembership {
  const TeamSeasonMembership({
    required this.teamId,
    required this.seasonId,
    required this.competitionId,
  });

  final int teamId;
  final int seasonId;
  final int competitionId;
}
