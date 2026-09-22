import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

/// Headers for private profile media served by the same authenticated API.
/// Uses the restored/login session, with the development token only in the
/// explicit skip-onboarding launch mode.
Map<String, String> get currentUserMediaRequestHeaders =>
    ApiConfig.currentAccessToken == null
        ? const {}
        : Map.unmodifiable({
            'Authorization': 'Bearer ${ApiConfig.currentAccessToken}',
          });

final CurrentUserRepository currentUserRepository = ApiCurrentUserRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
