import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/teams/mock/team_analysis_catalog.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

class MockTeamAttributeRepository implements TeamAttributeRepository {
  MockTeamAttributeRepository({List<TeamAttributeScores>? scores})
      : _scores = List.unmodifiable(scores ?? mockTeamAttributes);

  final List<TeamAttributeScores> _scores;

  @override
  Future<List<TeamAttributeScores>> loadForTeam(int teamId) async {
    final result = _scores.where((score) => score.teamId == teamId).toList()
      ..sort((a, b) => b.seasonId.compareTo(a.seasonId));
    return List.unmodifiable(result);
  }
}
