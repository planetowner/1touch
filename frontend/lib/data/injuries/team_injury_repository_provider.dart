import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';

final TeamInjuryRepository teamInjuryRepository = ApiTeamInjuryRepository(
  api: apiClient,
);
