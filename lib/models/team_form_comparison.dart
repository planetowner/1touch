class TeamFormPoint {
  final int round;
  final int points;

  const TeamFormPoint({required this.round, required this.points});

  factory TeamFormPoint.fromJson(Map<String, dynamic> json) {
    return TeamFormPoint(
      round: (json['round'] as num).toInt(),
      points: (json['points'] as num).toInt(),
    );
  }
}

class TeamFormSeries {
  final int teamId;
  final String seasonLabel;
  final List<TeamFormPoint> points;

  const TeamFormSeries({
    required this.teamId,
    required this.seasonLabel,
    required this.points,
  });

  factory TeamFormSeries.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>? ?? const [])
        .map((item) => TeamFormPoint.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.round.compareTo(b.round));

    return TeamFormSeries(
      teamId: (json['team_id'] as num).toInt(),
      seasonLabel: json['season_label'] as String,
      points: points,
    );
  }
}

class TeamFormComparison {
  final TeamFormSeries current;
  final List<TeamFormSeries> comparisons;

  const TeamFormComparison({
    required this.current,
    required this.comparisons,
  });

  factory TeamFormComparison.fromJson(Map<String, dynamic> json) {
    return TeamFormComparison(
      current: TeamFormSeries.fromJson(
        json['current'] as Map<String, dynamic>,
      ),
      comparisons: (json['comparisons'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                TeamFormSeries.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  static TeamFormComparison? tryFromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      return TeamFormComparison.fromJson(value);
    } on Object {
      return null;
    }
  }
}
