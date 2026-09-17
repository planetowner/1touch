import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Headers for private profile media served by the same authenticated API.
///
/// Replace this static development configuration with session-backed headers
/// when saved-login restoration becomes the app-wide authentication source.
Map<String, String> get currentUserMediaRequestHeaders =>
    _apiConfig.requestHeaders;

final CurrentUserRepository currentUserRepository = ApiCurrentUserRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
