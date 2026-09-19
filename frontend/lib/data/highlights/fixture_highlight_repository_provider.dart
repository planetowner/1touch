import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/highlights/api/api_fixture_highlight_repository.dart';
import 'package:onetouch/data/highlights/fixture_highlight_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final FixtureHighlightRepository fixtureHighlightRepository =
    ApiFixtureHighlightRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
