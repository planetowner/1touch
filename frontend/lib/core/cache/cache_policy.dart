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

enum CacheTier { staticData, standard, realtime, userData }

enum CacheFreshness { missing, fresh, stale }

/// Central policy for the first offline-first resources.
///
/// TTLs are product decisions and therefore live in one place instead of being
/// copied into screens or endpoint implementations.
abstract final class AppCachePolicy {
  static const staticTtl = Duration(days: 7);
  static const standardTtl = Duration(hours: 1);
  static const realtimeTtl = Duration.zero;

  static Duration? ttl(CacheTier tier) => switch (tier) {
        CacheTier.staticData => staticTtl,
        CacheTier.standard => standardTtl,
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
    final current = (now ?? DateTime.now()).toUtc();
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
