/// A season for which a team has stored attribute scores.
class TeamAttributeSeasonOption {
  const TeamAttributeSeasonOption({
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.isCurrent,
  });

  final int competitionId;
  final int seasonId;
  final String seasonName;
  final bool isCurrent;
}
