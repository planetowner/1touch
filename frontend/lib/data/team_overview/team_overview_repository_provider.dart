import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final TeamOverviewRepository teamOverviewRepository = ApiTeamOverviewRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
