part of 'player_comparison_screen.dart';

const List<String> _kRadarLabels = [
  'Pace',
  'Shooting',
  'Passing',
  'Defending',
  'Physical',
];

List<String> _seasonsForPeriod(PlayerClubPeriod period) {
  final from = int.tryParse(period.fromSeason.split('/').first);
  final to = int.tryParse(period.toSeason.split('/').first);
  if (from == null || to == null || to < from) {
    return [period.toSeason];
  }
  return [
    for (int year = from; year <= to; year++)
      '${year.toString().padLeft(2, '0')}/${(year + 1).toString().padLeft(2, '0')}',
  ];
}

ComparisonPlayer _toComparisonPlayer(Player player) {
  final stats = player.seasonStats;
  final clubSeasons = <String, List<String>>{};
  for (final period in player.clubHistory) {
    clubSeasons.putIfAbsent(period.club, () => <String>[]);
    clubSeasons[period.club]!.addAll(_seasonsForPeriod(period));
  }

  return ComparisonPlayer(
    id: player.id,
    fullName: player.fullName,
    shortName: player.shortName,
    team: player.teamName,
    number: player.jerseyNumber,
    teamColor: player.teamColor.first,
    playerImageAsset: player.imageAsset,
    teamLogoAsset: player.teamLogoAsset,
    headerTeamLogoAsset: player.teamLogoAsset,
    clubSeasons: clubSeasons,
    radarValues: player.radarValues,
    statCategories: [
      CompStatCategory(
        label: 'FINISH',
        rows: [
          CompStatRow(
            name: 'Goals',
            value: stats.goals.toDouble(),
            display: '${stats.goals}',
          ),
          CompStatRow(
            name: 'Goal Contributions',
            value: (stats.goals + stats.assists).toDouble(),
            display: '${stats.goals + stats.assists}',
          ),
        ],
      ),
      CompStatCategory(
        label: 'PLAY MAKING',
        rows: [
          CompStatRow(
            name: 'Assists',
            value: stats.assists.toDouble(),
            display: '${stats.assists}',
          ),
          CompStatRow(
            name: 'Passes',
            value: stats.passes.toDouble(),
            display: '${stats.passes}',
          ),
        ],
      ),
      CompStatCategory(
        label: 'SEASON',
        rows: [
          CompStatRow(
            name: 'Appearances',
            value: stats.appearances.toDouble(),
            display: '${stats.appearances}',
          ),
          CompStatRow(
            name: 'Average Rating',
            value: stats.rating,
            display: stats.rating.toStringAsFixed(1),
          ),
        ],
      ),
    ],
  );
}

final List<ComparisonPlayer> kComparisonPlayers = playerRepository.allPlayers
    .map(_toComparisonPlayer)
    .toList(growable: false);

const List<List<String>> _kMostCompared = [
  ['scott-mctominay', 'mohamed-salah'],
  ['lee-kang-in', 'kim-min-jae'],
  ['erling-haaland', 'kylian-mbappe'],
];

ComparisonPlayer? _findById(String id) {
  for (final player in kComparisonPlayers) {
    if (player.id == id) return player;
  }
  return null;
}
