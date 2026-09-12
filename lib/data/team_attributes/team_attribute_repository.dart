import 'package:onetouch/models/team_attribute_scores.dart';

abstract interface class TeamAttributeRepository {
  /// Returns the available scores for [teamId], newest first.
  ///
  /// Implementations return an immutable list and use an empty list when the
  /// team has no attribute data. The API implementation currently contains
  /// only the current season because the backend exposes one season per request
  /// without publishing a team-specific list of available attribute seasons.
  Future<List<TeamAttributeScores>> loadForTeam(int teamId);
}
