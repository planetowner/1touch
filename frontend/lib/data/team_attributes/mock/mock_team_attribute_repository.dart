import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/teams/mock/team_analysis_catalog.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

class MockTeamAttributeRepository implements TeamAttributeRepository {
  MockTeamAttributeRepository({List<TeamAttributeScores>? scores})
      : _scores = List.unmodifiable(scores ?? mockTeamAttributes);

  final List<TeamAttributeScores> _scores;

  @override
  Future<List<TeamAttributeSeasonOption>> loadOptionsForTeam(int teamId) async {
    final seasonsById = {
      for (final season in mockSeasons) season.seasonId: season,
    };
    final options = <int, TeamAttributeSeasonOption>{};
    for (final score in _scores.where((score) => score.teamId == teamId)) {
      final season = seasonsById[score.seasonId];
      options[score.seasonId] = TeamAttributeSeasonOption(
        competitionId: score.competitionId,
        seasonId: score.seasonId,
        seasonName: score.seasonLabel,
        isCurrent: season?.isCurrent ?? false,
      );
    }
    final result = options.values.toList()
      ..sort((a, b) => b.seasonId.compareTo(a.seasonId));
    return List.unmodifiable(result);
  }

  @override
  Future<List<TeamAttributeScores>> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final result = _scores
        .where(
          (score) =>
              score.teamId == teamId &&
              (seasonId == null || score.seasonId == seasonId),
        )
        .toList()
      ..sort((a, b) => b.seasonId.compareTo(a.seasonId));
    return List.unmodifiable(result);
  }
}
