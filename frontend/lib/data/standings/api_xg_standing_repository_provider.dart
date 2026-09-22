import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_repository.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

/// Real query provider used by the xG branch of the standings screen. The
/// legacy `xgStandingRepository` remains mock-backed for catalog consumers.
final XgStandingRepository apiXgStandingRepository = ApiXgStandingRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
