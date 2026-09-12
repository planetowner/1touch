import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final CurrentUserRepository currentUserRepository = ApiCurrentUserRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
