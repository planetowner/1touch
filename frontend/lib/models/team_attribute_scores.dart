class TeamAttributeScores {
  final int teamId;
  final int seasonId;
  final String seasonLabel;
  final double attack;
  final double progression;
  final double pressure;
  final double dominance;
  final double defense;
  final double possession;

  const TeamAttributeScores({
    required this.teamId,
    required this.seasonId,
    required this.seasonLabel,
    required this.attack,
    required this.progression,
    required this.pressure,
    required this.dominance,
    required this.defense,
    required this.possession,
  });

  List<double> get radarValues => [
        attack,
        progression,
        pressure,
        dominance,
        defense,
        possession,
      ];
}
