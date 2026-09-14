import 'package:onetouch/data/standings/api/api_standing_response.dart';
import 'package:onetouch/models/standing.dart';

List<Standing> standingsFromApiResponse(
  ApiCompetitionStandingsResponse response,
) {
  final teamIds = <int>{};
  final positions = <int>{};
  final standings = response.rows.map((row) {
    if (!teamIds.add(row.teamId)) {
      throw StateError('Duplicate standing team_id ${row.teamId}.');
    }
    if (!positions.add(row.position)) {
      throw StateError('Duplicate standing position ${row.position}.');
    }
    return Standing(
      competitionId: response.competitionId,
      seasonId: response.seasonId,
      phase: StandingPhase.league,
      groupName: '',
      teamId: row.teamId,
      teamName: row.teamName,
      teamLogo: row.teamLogo,
      position: row.position,
      rankDelta: row.rankDelta,
      matchesPlayed: row.matchesPlayed,
      won: row.won,
      draw: row.draw,
      lost: row.lost,
      goalsFor: row.goalsFor,
      goalsAgainst: row.goalsAgainst,
      goalDiff: row.goalDiff,
      points: row.points,
      last5Form: row.lastFiveForm,
    );
  }).toList()
    ..sort((a, b) {
      final positionComparison = a.position.compareTo(b.position);
      return positionComparison != 0
          ? positionComparison
          : a.teamId.compareTo(b.teamId);
    });
  return List.unmodifiable(standings);
}
