// SQL table: teams
// team_id | name | short_code | image_path | primary_color

class Team {
  final int teamId;
  final String name;
  final String? shortCode;
  final String? imagePath;
  // Stored as ARGB int. SQL: primary_color INT DEFAULT 0xFFD82457
  final int primaryColor;

  const Team({
    required this.teamId,
    required this.name,
    this.shortCode,
    this.imagePath,
    this.primaryColor = 0xFFD82457,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId:       json['team_id'] as int,
      name:         json['name'] as String,
      shortCode:    json['short_code'] as String?,
      imagePath:    json['image_path'] as String?,
      primaryColor: json['primary_color'] as int? ?? 0xFFD82457,
    );
  }
}