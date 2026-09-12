import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';

final FixtureRepository fixtureRepository = MockFixtureRepository();

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Query-specific API provider used while catalog-based fixture screens remain
/// on [fixtureRepository].
final FixtureRepository fixtureDetailRepository = ApiFixtureRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
