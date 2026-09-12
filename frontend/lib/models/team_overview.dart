import 'package:onetouch/models/fixture.dart';

/// UI aggregate for the Home/Team screens: a team plus its derived
/// standing and live/next/last fixtures. Distinct from the schema-aligned
/// [Team] in models/team.dart.
class TeamOverview {
  final int id;
  final String name;
  final String shortName;
  final String imagePath;

  // Derived fields — populated from API responses (standings, fixtures)
  // not stored in the teams table itself
  final Map<String, dynamic>? standing;
  final Fixture? liveMatch;
  final Fixture? nextMatch;
  final Fixture? lastMatch;

  TeamOverview({
    required this.id,
    required this.name,
    required this.shortName,
    required this.imagePath,
    this.standing,
    this.liveMatch,
    this.nextMatch,
    this.lastMatch,
  });

  factory TeamOverview.fromJson(Map<String, dynamic> json) {
    return TeamOverview(
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
