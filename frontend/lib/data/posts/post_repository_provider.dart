import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';

final PostRepository postRepository = ApiPostRepository(
  api: apiClient,
);
