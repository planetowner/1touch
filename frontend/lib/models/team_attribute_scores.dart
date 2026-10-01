const teamAttributeLabels = <String>[
  'Possession & Build-Up',
  'Attacking Threat',
  'Chance Creation',
  'Shooting & Finishing',
  'Defending',
];

class TeamAttributeScores {
  final int teamId;
  final int competitionId;
  final int seasonId;
  final String seasonLabel;
  final double shootingFinishing;
  final double attackingThreat;
  final double chanceCreation;
  final double defending;
  final double possessionBuildUp;

  const TeamAttributeScores({
    required this.teamId,
    required this.competitionId,
    required this.seasonId,
    required this.seasonLabel,
    required this.shootingFinishing,
    required this.attackingThreat,
    required this.chanceCreation,
    required this.defending,
    required this.possessionBuildUp,
  });

  List<double> get radarValues => [
        possessionBuildUp,
        attackingThreat,
        chanceCreation,
        shootingFinishing,
        defending,
      ];
}
