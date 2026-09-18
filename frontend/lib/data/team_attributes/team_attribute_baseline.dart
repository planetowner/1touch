import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

/// Shared baseline selection for the team page and match preview.
Future<
        ({
          List<TeamAttributeScores> scores,
          List<TeamAttributeSeasonOption> options
        })>
    loadTeamAttributeBaseline(
        TeamAttributeRepository repository, int teamId) async {
  final List<TeamAttributeSeasonOption> options;
  try {
    options = await repository.loadOptionsForTeam(teamId);
  } on Object {
    // Preserve the team page's current-season fallback on options failures.
    return (
      scores: await repository.loadForTeam(teamId),
      options: const <TeamAttributeSeasonOption>[],
    );
  }
  if (options.isEmpty) {
    return (scores: const <TeamAttributeScores>[], options: options);
  }
  final baseline = options.firstWhere(
    (option) => option.isCurrent,
    orElse: () => options.first,
  );
  return (
    scores: await repository.loadForTeam(teamId, seasonId: baseline.seasonId),
    options: options,
  );
}
