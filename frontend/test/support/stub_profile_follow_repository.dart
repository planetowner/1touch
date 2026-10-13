import 'package:onetouch/data/profile/profile_follow_repository.dart';
import 'package:onetouch/models/profile_follow.dart';

class StubProfileFollowRepository implements ProfileFollowRepository {
  const StubProfileFollowRepository({
    this.counts = const ProfileFollowCounts(followers: 200, following: 150),
    this.followers = const [],
    this.following = const [],
  });

  final ProfileFollowCounts counts;
  final List<ProfileFollowUser> followers;
  final List<ProfileFollowUser> following;

  @override
  Future<ProfileFollowCounts> loadCounts() async => counts;

  @override
  Future<List<ProfileFollowUser>> loadUsers({
    required ProfileFollowTab tab,
    required ProfileFollowSort sort,
    int limit = 50,
    int offset = 0,
  }) async {
    final source = tab == ProfileFollowTab.followers ? followers : following;
    return source.skip(offset).take(limit).toList();
  }

  @override
  Future<void> unfollow(int userId) async {}
}
