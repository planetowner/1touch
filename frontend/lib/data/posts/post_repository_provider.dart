import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final PostRepository postRepository = ApiPostRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
