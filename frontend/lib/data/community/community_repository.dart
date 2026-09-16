import 'package:onetouch/models/community_rules.dart';

abstract interface class CommunityRepository {
  Future<int> loadFollowerCount({required int teamId});

  Future<CommunityRules> loadRules({
    required int teamId,
    required CommunityLanguage language,
  });
}
