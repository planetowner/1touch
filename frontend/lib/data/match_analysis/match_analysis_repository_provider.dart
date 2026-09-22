import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/match_analysis/api/api_match_analysis_repository.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final MatchAnalysisRepository matchAnalysisRepository =
    ApiMatchAnalysisRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
