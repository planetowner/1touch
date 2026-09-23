import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';

final TeamProbabilityRepository teamProbabilityRepository =
    ApiTeamProbabilityRepository(
  api: apiClient,
);
