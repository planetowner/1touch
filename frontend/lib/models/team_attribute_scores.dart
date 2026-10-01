const teamAttributeLabels = <String>[
  'Shooting & Finishing',
  'Attacking Threat',
  'Chance Creation',
  'Defending',
  'Possession & Build-Up',
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
        shootingFinishing,
        attackingThreat,
        chanceCreation,
        defending,
        possessionBuildUp,
      ];
}
