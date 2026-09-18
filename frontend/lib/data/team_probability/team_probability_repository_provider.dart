import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final TeamProbabilityRepository teamProbabilityRepository =
    ApiTeamProbabilityRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
