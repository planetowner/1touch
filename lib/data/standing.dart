class StandingRowOut {
  final int position;
  final int teamId;
  final String? teamName;
  final String? teamLogo;

  final int matchesPlayed;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;

  final List<String> last5Form;

  const StandingRowOut({
    required this.position,
    required this.teamId,
    this.teamName,
    this.teamLogo,
    required this.matchesPlayed,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    this.last5Form = const [],
  });
}