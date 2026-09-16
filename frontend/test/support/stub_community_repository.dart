import 'package:onetouch/data/community/community_repository.dart';

class StubCommunityRepository implements CommunityRepository {
  const StubCommunityRepository({this.followerCount = 0});

  final int followerCount;

  @override
  Future<int> loadFollowerCount({required int teamId}) async => followerCount;
}
