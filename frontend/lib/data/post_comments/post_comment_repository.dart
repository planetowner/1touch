import 'package:onetouch/models/post_comment.dart';

abstract interface class PostCommentRepository {
  Future<List<PostComment>> loadForPost({
    required int postId,
    int afterId = 0,
    int limit = 50,
  });
}
