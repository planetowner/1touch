import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/models/community_rules.dart';

class StubCommunityRepository implements CommunityRepository {
  const StubCommunityRepository({this.followerCount = 0});

  final int followerCount;

  @override
  Future<int> loadFollowerCount({required int teamId}) async => followerCount;

  @override
  Future<CommunityRules> loadRules({
    required int teamId,
    required CommunityLanguage language,
  }) {
    throw UnsupportedError('This stub only provides follower counts.');
  }
}
