import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only acknowledgment until the server exposes a rules-read contract.
abstract interface class CommunityRulesVisitRepository {
  Future<bool> shouldShow();

  Future<void> acknowledge();
}

class LocalCommunityRulesVisitRepository
    implements CommunityRulesVisitRepository {
  LocalCommunityRulesVisitRepository({Future<int?> Function()? loadUserId})
      : _loadUserId = loadUserId ?? _cachedUserId;

  static const _keyPrefix = 'community.rules.acknowledged.v1.';
  final Future<int?> Function() _loadUserId;

  static Future<int?> _cachedUserId() async =>
      (await currentUserRepository.loadCachedAccount())?.userId;

  @override
  Future<bool> shouldShow() async {
    final userId = await _loadUserId();
    if (userId == null) return false;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('$_keyPrefix$userId') != true;
  }

  @override
  Future<void> acknowledge() async {
    final userId = await _loadUserId();
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_keyPrefix$userId', true);
  }
}
