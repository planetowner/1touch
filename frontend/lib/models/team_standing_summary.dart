class TeamStandingSummary {
  final int position;
  final int? rankDelta;

  const TeamStandingSummary({
    required this.position,
    this.rankDelta,
  });

  factory TeamStandingSummary.fromJson(Map<String, dynamic> json) {
    return TeamStandingSummary(
      position: json['position'] as int,
      rankDelta: json['rank_delta'] as int?,
    );
  }
}
