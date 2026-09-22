// Current SQL table: teams
// team_id | name | short_name | short_code | image_path

class Team {
  final int teamId;
  final String name;
  final String? shortName;
  final String? shortCode;
  final String? imagePath;
  // Stored as an ARGB int for Flutter rendering.
  final int primaryColor;

  const Team({
    required this.teamId,
    required this.name,
    this.shortName,
    this.shortCode,
    this.imagePath,
    this.primaryColor = 0xFFD82457,
  });

  // 짧은 이름을 지정하지 않은 팀은 원래 이름을 그대로 보여줘요.
  String get displayName => shortName ?? name;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId: json['team_id'] as int,
      name: json['name'] as String,
      shortName: json['short_name'] as String?,
      shortCode: json['short_code'] as String?,
      imagePath: json['image_path'] as String?,
      primaryColor: json['primary_color'] as int? ?? 0xFFD82457,
    );
  }
}
