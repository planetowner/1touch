import 'package:onetouch/data/team_trophies/team_trophy_repository.dart';
import 'package:onetouch/data/teams/mock/team_trophy_catalog.dart';
import 'package:onetouch/models/team_trophy.dart';

class MockTeamTrophyRepository implements TeamTrophyRepository {
  MockTeamTrophyRepository({List<TeamTrophy>? trophies})
      : _trophies = List.unmodifiable(trophies ?? mockTeamTrophies);

  final List<TeamTrophy> _trophies;

  @override
  List<TeamTrophy> forTeamSeason(int teamId, String seasonLabel) {
    return List.unmodifiable(
      _trophies.where(
        (trophy) =>
            trophy.teamId == teamId && trophy.seasonLabel == seasonLabel,
      ),
    );
  }
}
