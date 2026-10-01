import 'package:onetouch/data/profile/profile_activity_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/profile_activity_counts.dart';
import 'package:onetouch/models/profile_comment_activity.dart';

class StubProfileActivityRepository implements ProfileActivityRepository {
  const StubProfileActivityRepository();

  @override
  Future<ProfileActivityCounts> loadCounts() async =>
      const ProfileActivityCounts(postCount: 0, commentCount: 0);

  @override
  Future<List<Post>> loadPosts({int limit = 50, int offset = 0}) async => [];

  @override
  Future<List<ProfileCommentActivity>> loadComments({
    int limit = 50,
    int offset = 0,
  }) async =>
      [];
}
