import 'package:onetouch/models/profile_follow.dart';

abstract interface class ProfileFollowRepository {
  Future<ProfileFollowCounts> loadCounts();

  Future<List<ProfileFollowUser>> loadUsers({
    required ProfileFollowTab tab,
    required ProfileFollowSort sort,
    int limit = 50,
    int offset = 0,
  });

  Future<void> unfollow(int userId);
}
