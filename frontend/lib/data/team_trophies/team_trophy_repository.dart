import 'package:onetouch/models/team_trophy.dart';

abstract interface class TeamTrophyRepository {
  List<TeamTrophy> forTeamSeason(int teamId, String seasonLabel);
}
