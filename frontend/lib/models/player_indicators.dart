class PlayerIndicatorScore {
  const PlayerIndicatorScore({
    required this.grade,
    required this.band,
    required this.percentile,
    required this.referenceCount,
    required this.ratedMatches,
    this.unavailableReason,
  });

  final String? grade;
  final int? band;
  final double? percentile;
  final int referenceCount;
  final int ratedMatches;
  final String? unavailableReason;
}

class PlayerIndicators {
  const PlayerIndicators({
    required this.playerId,
    required this.seasonName,
    required this.asOf,
    required this.form,
    required this.costEffectiveness,
    this.squadRole,
  });

  final int playerId;
  final String seasonName;
  final DateTime asOf;
  final PlayerIndicatorScore form;
  final PlayerIndicatorScore costEffectiveness;
  final String? squadRole;
}
