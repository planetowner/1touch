import 'package:onetouch/data/teams/mock/mock_team_competition_context_resolver.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_repository.dart';

final TeamRepository teamRepository = MockTeamRepository();
final TeamCompetitionContextResolver teamCompetitionContextResolver =
    MockTeamCompetitionContextResolver();
