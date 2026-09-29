import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/profile_comment_activity.dart';

abstract interface class ProfileActivityRepository {
  Future<List<Post>> loadPosts({int limit = 50, int offset = 0});

  Future<List<ProfileCommentActivity>> loadComments({
    int limit = 50,
    int offset = 0,
  });
}
