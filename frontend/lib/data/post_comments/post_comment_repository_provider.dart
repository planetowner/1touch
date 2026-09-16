import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final PostCommentRepository postCommentRepository = ApiPostCommentRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
