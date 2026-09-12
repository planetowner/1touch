import 'package:onetouch/models/team_attribute_scores.dart';

abstract interface class TeamAttributeRepository {
  /// Returns every available season for [teamId], newest first.
  ///
  /// Implementations return an immutable list and use an empty list when the
  /// team has no attribute data.
  Future<List<TeamAttributeScores>> loadForTeam(int teamId);
}
