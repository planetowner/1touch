import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/core/viewer_country_config.dart';
import 'package:onetouch/data/home/api/api_home_repository.dart';
import 'package:onetouch/data/home/home_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final HomeRepository homeRepository = ApiHomeRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
  viewerCountry: ViewerCountryConfig.fromEnvironment(),
);
