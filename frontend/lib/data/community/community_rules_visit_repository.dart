import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 확인 기록은 기기에 저장해요. 다른 기기와는 동기화하지 않아요.
abstract interface class CommunityRulesVisitRepository {
  Future<bool> shouldShow({DateTime? suspensionEndsAt});

  Future<void> acknowledge({DateTime? suspensionEndsAt});
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
  Future<bool> shouldShow({DateTime? suspensionEndsAt}) async {
    final userId = await _loadUserId();
    if (userId == null) return false;
    final preferences = await SharedPreferences.getInstance();
    if (suspensionEndsAt != null) {
      return preferences.getString('$_keyPrefix$userId.suspension') !=
          suspensionEndsAt.toUtc().toIso8601String();
    }
    return preferences.getBool('$_keyPrefix$userId') != true;
  }

  @override
  Future<void> acknowledge({DateTime? suspensionEndsAt}) async {
    final userId = await _loadUserId();
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_keyPrefix$userId', true);
    if (suspensionEndsAt != null) {
      // 일반 첫 방문 확인과 구분해야 새 제재 뒤에도 복귀 안내를 보여줄 수 있어요.
      await preferences.setString('$_keyPrefix$userId.suspension',
          suspensionEndsAt.toUtc().toIso8601String());
    }
  }
}
