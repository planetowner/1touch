import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/profile/api/api_profile_avatar_repository.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final ProfileAvatarRepository profileAvatarRepository =
    ApiProfileAvatarRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
