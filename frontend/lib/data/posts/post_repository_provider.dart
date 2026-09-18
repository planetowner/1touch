import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final PostRepository postRepository = ApiPostRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
