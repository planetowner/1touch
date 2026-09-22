import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/community/api/api_community_repository.dart';
import 'package:onetouch/data/community/community_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final CommunityRepository communityRepository = ApiCommunityRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
