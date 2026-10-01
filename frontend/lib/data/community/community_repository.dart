import 'package:onetouch/models/community_rules.dart';
import 'package:onetouch/models/community_ban.dart';

abstract interface class CommunityRepository {
  Future<CommunityBanStatus?> loadBanStatus();

  Future<int> loadFollowerCount({required int teamId});

  Future<CommunityRules> loadRules({
    required int teamId,
  });
}
