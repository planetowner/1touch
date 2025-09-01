import 'matchdata.dart';

class Team {
  final int id;
  final String name;
  final String shortName;
  final String imagePath;
  final int countryId;
  final Map<String, dynamic>? standing;
  final Match? nextMatch;

  Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.imagePath,
    required this.countryId,
    required this.standing,
    required this.nextMatch,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      shortName: json['short_code'],
      imagePath: json['image_path'],
      countryId: json['country_id'],
      standing: json['standing'],
      nextMatch: json['nextMatch'] != null
          ? Match.fromJson(json['nextMatch'])
          : null,
    );
  }
}