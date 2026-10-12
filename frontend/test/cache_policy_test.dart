import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/cache/cache_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29, 12);

  test('keeps static data fresh for seven days', () {
    expect(AppCachePolicy.staticTtl, const Duration(days: 7));
    expect(
      AppCachePolicy.freshness(
        CacheTier.staticData,
        savedAt: now.subtract(const Duration(days: 6)),
        now: now,
      ),
      CacheFreshness.fresh,
    );
    expect(
      AppCachePolicy.freshness(
        CacheTier.staticData,
        savedAt: now.subtract(const Duration(days: 7)),
        now: now,
      ),
      CacheFreshness.stale,
    );
  });

  test('keeps standard data fresh for fifteen minutes', () {
    expect(AppCachePolicy.standardTtl, const Duration(minutes: 15));
    expect(
      AppCachePolicy.freshness(
        CacheTier.standard,
        savedAt: now.subtract(const Duration(minutes: 14, seconds: 59)),
        now: now,
      ),
      CacheFreshness.fresh,
    );
    expect(
      AppCachePolicy.freshness(
        CacheTier.standard,
        savedAt: now.subtract(const Duration(minutes: 15)),
        now: now,
      ),
      CacheFreshness.stale,
    );
  });

  test('keeps extended data fresh for one hour', () {
    expect(AppCachePolicy.extendedTtl, const Duration(hours: 1));
    expect(
      AppCachePolicy.freshness(
        CacheTier.extended,
        savedAt: now.subtract(const Duration(minutes: 59, seconds: 59)),
        now: now,
      ),
      CacheFreshness.fresh,
    );
    expect(
      AppCachePolicy.freshness(
        CacheTier.extended,
        savedAt: now.subtract(const Duration(hours: 1)),
        now: now,
      ),
      CacheFreshness.stale,
    );
  });

  test('lists, standings and community become stale after one minute', () {
    expect(AppCachePolicy.shortLivedTtl, const Duration(minutes: 1));
    expect(
      AppCachePolicy.freshness(
        CacheTier.shortLived,
        savedAt: now.subtract(const Duration(seconds: 59)),
        now: now,
      ),
      CacheFreshness.fresh,
    );
    expect(
      AppCachePolicy.freshness(
        CacheTier.shortLived,
        savedAt: now.subtract(const Duration(minutes: 1)),
        now: now,
      ),
      CacheFreshness.stale,
    );
  });

  test('force refresh and realtime always use the network', () {
    expect(
      AppCachePolicy.shouldRefresh(
        tier: CacheTier.staticData,
        trigger: CacheSyncTrigger.userRefresh,
        savedAt: now,
      ),
      isTrue,
    );
    expect(
      AppCachePolicy.shouldRefresh(
        tier: CacheTier.realtime,
        trigger: CacheSyncTrigger.screenEnter,
        savedAt: now,
      ),
      isTrue,
    );
  });

  test('user data syncs by session and mutation instead of elapsed time', () {
    expect(
      AppCachePolicy.shouldRefresh(
        tier: CacheTier.userData,
        trigger: CacheSyncTrigger.bootstrap,
        savedAt: now,
      ),
      isTrue,
    );
    expect(
      AppCachePolicy.shouldRefresh(
        tier: CacheTier.userData,
        trigger: CacheSyncTrigger.mutation,
        savedAt: now,
      ),
      isTrue,
    );
    expect(
      AppCachePolicy.shouldRefresh(
        tier: CacheTier.userData,
        trigger: CacheSyncTrigger.foreground,
        savedAt: now,
      ),
      isFalse,
    );
  });
}
