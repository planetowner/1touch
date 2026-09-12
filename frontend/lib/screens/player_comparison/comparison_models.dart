part of 'player_comparison_screen.dart';

class ComparisonPlayer {
  final String id;
  final String fullName;
  final String shortName;
  final String team;
  final int number;
  final Color teamColor;
  final String? playerImageAsset;
  final String? teamLogoAsset;
  final String? headerTeamLogoAsset;
  final Map<String, List<String>> clubSeasons;
  final List<double> radarValues;
  final List<CompStatCategory> statCategories;

  const ComparisonPlayer({
    required this.id,
    required this.fullName,
    required this.shortName,
    required this.team,
    required this.number,
    required this.teamColor,
    this.playerImageAsset,
    this.teamLogoAsset,
    this.headerTeamLogoAsset,
    required this.clubSeasons,
    required this.radarValues,
    required this.statCategories,
  });
}

class CompStatCategory {
  final String label;
  final List<CompStatRow> rows;

  const CompStatCategory({required this.label, required this.rows});
}

class CompStatRow {
  final String name;
  final double value;
  final String display;

  const CompStatRow({
    required this.name,
    required this.value,
    required this.display,
  });
}
