enum TeamTrophyType {
  domesticLeague,
  domesticCup,
  domesticSuperCup,
  continental,
  world,
}

class TeamTrophy {
  final String id;
  final int teamId;
  final String seasonLabel;
  final String name;
  final String competitionCode;
  final TeamTrophyType type;

  const TeamTrophy({
    required this.id,
    required this.teamId,
    required this.seasonLabel,
    required this.name,
    required this.competitionCode,
    required this.type,
  });
}
