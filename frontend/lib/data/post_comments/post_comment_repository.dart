import 'package:onetouch/models/post_comment.dart';

const int maxPostCommentBodyLength = 5000;

abstract interface class PostCommentRepository {
  Future<List<PostComment>> loadForPost({
    required int postId,
    int afterId = 0,
    int limit = 50,
  });

  Future<int> createComment({
    required int postId,
    required String body,
    int? replyToId,
  });
}
