import 'package:onetouch/data/standings/api/api_xg_standing_response.dart';
import 'package:onetouch/models/standing.dart';

List<XgStanding> xgStandingsFromApiResponse(
  ApiCompetitionXgStandingsResponse response,
) {
  final teamIds = <int>{};
  final positions = <int>{};
  final standings = response.rows.map((row) {
    if (!teamIds.add(row.teamId)) {
      throw StateError('Duplicate xG standing team_id ${row.teamId}.');
    }
    if (!positions.add(row.position)) {
      throw StateError('Duplicate xG standing position ${row.position}.');
    }
    return XgStanding(
      competitionId: response.competitionId,
      seasonId: response.seasonId,
      teamId: row.teamId,
      teamName: row.teamName,
      teamLogo: row.teamLogo,
      position: row.position,
      matchesPlayed: row.matchesPlayed,
      xg: row.xg,
      xga: row.xga,
      xpts: row.xpts,
      provider: response.provider,
      xptsMethod: response.xptsMethod,
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
