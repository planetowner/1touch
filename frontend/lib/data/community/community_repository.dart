abstract interface class CommunityRepository {
  Future<int> loadFollowerCount({required int teamId});
}
