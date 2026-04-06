class FixtureOut {
  final int fixtureId;
  final int leagueId;
  final int seasonId;
  final String? competitionType;
  final String? roundName;
  final int? stageId;
  final int? groupId;
  final int? legNumber;

  final String status;
  final String? startingAt;

  final int homeTeamId;
  final int awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final int? homePenaltyScore;
  final int? awayPenaltyScore;

  final String? homeTeamName;
  final String? awayTeamName;
  final String? homeTeamLogo;
  final String? awayTeamLogo;

  const FixtureOut({
    required this.fixtureId,
    required this.leagueId,
    required this.seasonId,
    this.competitionType,
    this.roundName,
    this.stageId,
    this.groupId,
    this.legNumber,
    required this.status,
    this.startingAt,
    required this.homeTeamId,
    required this.awayTeamId,
    this.homeScore,
    this.awayScore,
    this.homePenaltyScore,
    this.awayPenaltyScore,
    this.homeTeamName,
    this.awayTeamName,
    this.homeTeamLogo,
    this.awayTeamLogo,
  });
}