import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final TeamInjuryRepository teamInjuryRepository = ApiTeamInjuryRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
