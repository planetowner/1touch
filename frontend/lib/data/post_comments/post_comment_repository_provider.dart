import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';

final PostCommentRepository postCommentRepository = ApiPostCommentRepository(
  api: apiClient,
);
