import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/community/api/api_community_repository.dart';
import 'package:onetouch/data/community/community_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final CommunityRepository communityRepository = ApiCommunityRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
