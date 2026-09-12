// SQL table: competitions
// competition_id | name | image_path
class Competition {
  final int competitionId;
  final String name;
  final String? imagePath;

  const Competition({
    required this.competitionId,
    required this.name,
    this.imagePath,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      competitionId: json['competition_id'] as int,
      name: json['name'] as String,
      imagePath: json['image_path'] as String?,
    );
  }
}
