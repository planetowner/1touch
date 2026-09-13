import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_repository.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final TeamAttributeRepository teamAttributeRepository =
    ApiTeamAttributeRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
