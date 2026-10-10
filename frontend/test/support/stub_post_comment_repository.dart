import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/models/post_comment.dart';

class StubPostCommentRepository implements PostCommentRepository {
  @override
  Future<void> setCommentLiked(
      {required int commentId, required bool liked}) async {}
  @override
  Future<void> reportComment(
      {required int commentId, required String reason}) async {}

  const StubPostCommentRepository({this.comments = const []});

  final List<PostComment> comments;

  @override
  Future<int> createComment({
    required int postId,
    required String body,
    int? replyToId,
  }) {
    throw UnsupportedError('This stub only provides comment loading.');
  }

  @override
  Future<void> deleteComment({required int commentId}) {
    throw UnsupportedError('This stub only provides comment loading.');
  }

  @override
  Future<void> updateComment({required int commentId, required String body}) {
    throw UnsupportedError('This stub only provides comment loading.');
  }

  @override
  Future<List<PostComment>> loadForPost({
    required int postId,
    int afterId = 0,
    int limit = 50,
  }) async {
    return List.unmodifiable(comments);
  }
}
