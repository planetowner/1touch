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

  Future<void> setCommentLiked({required int commentId, required bool liked});
  Future<void> reportComment({required int commentId, required String reason});

  Future<void> deleteComment({required int commentId});

  Future<void> updateComment({required int commentId, required String body});
}
