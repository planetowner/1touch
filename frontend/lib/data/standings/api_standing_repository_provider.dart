import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/standings/api/api_standing_repository.dart';
import 'package:onetouch/data/standings/standing_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Staged real provider. The Standing screen will adopt this in the next step;
/// the existing `standingRepository` remains mock-backed until it awaits loads.
final StandingRepository apiStandingRepository = ApiStandingRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
