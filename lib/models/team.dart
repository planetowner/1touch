// SQL table: teams
// team_id | name | short_code | image_path

class Team {
  final int teamId;
  final String name;
  final String? shortCode;
  final String? imagePath;

  const Team({
    required this.teamId,
    required this.name,
    this.shortCode,
    this.imagePath,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId:    json['team_id'] as int,
      name:      json['name'] as String,
      shortCode: json['short_code'] as String?,
      imagePath: json['image_path'] as String?,
    );
  }
}