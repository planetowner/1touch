import 'package:onetouch/data/team_trophies/mock/mock_team_trophy_repository.dart';
import 'package:onetouch/data/team_trophies/team_trophy_repository.dart';

// TODO(team-trophies): Replace this mock-backed provider after the backend
// exposes a trophy/honours endpoint and response contract.
final TeamTrophyRepository teamTrophyRepository = MockTeamTrophyRepository();
