// SQL table: competitions
// competition_id | name | short_code | image_path
class Competition {
  final int competitionId;
  final String name;
  final String? shortCode;
  final String? imagePath;

  const Competition({
    required this.competitionId,
    required this.name,
    this.shortCode,
    this.imagePath,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      competitionId: json['competition_id'] as int,
      name: json['name'] as String,
      shortCode: json['short_code'] as String?,
      imagePath: json['image_path'] as String?,
    );
  }
}
