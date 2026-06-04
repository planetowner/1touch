import 'package:onetouch/models/fixture.dart';


class Team {
  // Matches SQL `teams` table: team_id, name, short_code, image_path
  final int id;
  final String name;
  final String shortName;
  final String imagePath;

  // Derived fields — populated from API responses (standings, fixtures)
  // not stored in the teams table itself
  final Map<String, dynamic>? standing;
  final Fixture? nextMatch;
  final Fixture? lastMatch;

  Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.imagePath,
    this.standing,
    this.nextMatch,
    this.lastMatch,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['team_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      shortName: json['short_code'] ?? '',
      imagePath: json['image_path'] ?? '',
      standing: json['standing'] as Map<String, dynamic>?,
      nextMatch: json['next_match'] != null
          ? Fixture.fromJson(json['next_match'])
          : null,
      lastMatch: json['last_match'] != null
          ? Fixture.fromJson(json['last_match'])
          : null,
    );
  }
}