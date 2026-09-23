// 시즌 날짜는 DB에서 제거되어 이름과 현재 시즌 여부로 정렬해요.

class Season {
  final int seasonId;
  final int competitionId;
  final String name;
  final bool isCurrent;
  final String? startingAt;
  final String? endingAt;

  const Season({
    required this.seasonId,
    required this.competitionId,
    required this.name,
    required this.isCurrent,
    this.startingAt,
    this.endingAt,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonId: json['season_id'] as int,
      competitionId: json['competition_id'] as int,
      name: json['name'] as String,
      isCurrent: json['is_current'] as bool,
    );
  }
}
