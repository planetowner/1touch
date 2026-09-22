import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/profile/api/api_profile_avatar_repository.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final ProfileAvatarRepository profileAvatarRepository =
    ApiProfileAvatarRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
