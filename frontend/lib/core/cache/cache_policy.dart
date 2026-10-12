import 'package:clock/clock.dart';

/// Events that are allowed to synchronize local data with the server.
///
/// Cache freshness is event-driven instead of being controlled by unrelated
/// timers spread across screens. Repositories can still ignore triggers that
/// do not apply to their data class.
enum CacheSyncTrigger {
  bootstrap,
  foreground,
  screenEnter,
  userRefresh,
  mutation,
}

enum CacheTier {
  staticData,
  extended,
  standard,
  shortLived,
  realtime,
  userData
}

enum CacheFreshness { missing, fresh, stale }

/// Central policy for the first offline-first resources.
///
/// TTLs are product decisions and therefore live in one place instead of being
/// copied into screens or endpoint implementations.
abstract final class AppCachePolicy {
  // 대회·시즌 기준정보는 오래 보관하고, 경기로 바뀌는 데이터는 더 자주 확인해요.
  static const staticTtl = Duration(days: 7);
  // 종료 경기 상세도 늦게 수집된 기록과 정정 결과를 반영해야 해요.
  static const extendedTtl = Duration(hours: 1);
  static const standardTtl = Duration(minutes: 15);
  // 경기 목록·순위·피드는 새 항목이 생기므로 정적 데이터로 취급하지 않아요.
  static const shortLivedTtl = Duration(minutes: 1);
  static const realtimeTtl = Duration.zero;

  static Duration? ttl(CacheTier tier) => switch (tier) {
        CacheTier.staticData => staticTtl,
        CacheTier.extended => extendedTtl,
        CacheTier.standard => standardTtl,
        CacheTier.shortLived => shortLivedTtl,
        CacheTier.realtime => realtimeTtl,
        // User data is synchronized once per authenticated session and after
        // successful mutations, rather than by an arbitrary elapsed duration.
        CacheTier.userData => null,
      };

  static CacheFreshness freshness(
    CacheTier tier, {
    required DateTime? savedAt,
    DateTime? now,
  }) {
    if (savedAt == null) return CacheFreshness.missing;
    final duration = ttl(tier);
    if (duration == null) return CacheFreshness.fresh;
    final current = (now ?? clock.now()).toUtc();
    return current.difference(savedAt.toUtc()) < duration
        ? CacheFreshness.fresh
        : CacheFreshness.stale;
  }

  /// All five conventional triggers pass through this single decision point.
  static bool shouldRefresh({
    required CacheTier tier,
    required CacheSyncTrigger trigger,
    required DateTime? savedAt,
  }) {
    if (trigger == CacheSyncTrigger.userRefresh) return true;
    if (tier == CacheTier.realtime) return true;
    if (tier == CacheTier.userData) {
      return trigger == CacheSyncTrigger.bootstrap ||
          trigger == CacheSyncTrigger.mutation;
    }
    if (trigger == CacheSyncTrigger.mutation) return false;
    return freshness(tier, savedAt: savedAt) != CacheFreshness.fresh;
  }
}
