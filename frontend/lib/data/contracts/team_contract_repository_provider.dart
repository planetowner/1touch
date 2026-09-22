import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_repository.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final TeamContractRepository teamContractRepository = ApiTeamContractRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
