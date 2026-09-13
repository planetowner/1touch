import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

abstract interface class TeamAttributeRepository {
  /// Returns seasons that have stored attribute scores for [teamId].
  Future<List<TeamAttributeSeasonOption>> loadOptionsForTeam(int teamId);

  /// Returns the available scores for [teamId], newest first.
  ///
  /// When [seasonId] is supplied, only that season is returned.
  ///
  /// Implementations return an immutable list and use an empty list when the
  /// team has no attribute data. The API returns one season per request.
  Future<List<TeamAttributeScores>> loadForTeam(
    int teamId, {
    int? seasonId,
  });
}
