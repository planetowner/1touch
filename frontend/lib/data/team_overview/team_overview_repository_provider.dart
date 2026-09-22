import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final TeamOverviewRepository teamOverviewRepository = ApiTeamOverviewRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
