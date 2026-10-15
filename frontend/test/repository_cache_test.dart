import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/repository_cache.dart';

void main() {
  test('an invalidated response cannot repopulate memory or disk', () async {
    final store = MemoryLocalCacheStore();
    final pending = Completer<Map<String, dynamic>>();
    final cache = _cache(store, (_) => pending.future);
    final oldRequest = cache.refresh(1);
    await cache.invalidate();
    pending.complete({'value': 'previous account'});
    await oldRequest;
    expect(cache.cached(1), isNull);
    expect(await cache.restore(1), isNull);
  });

  test('invalidation drains pending writes before clearing a shared scope',
      () async {
    final store = _DelayedWriteStore();
    final feeds = _cache(store, (_) async => {'value': 'feed'});
    final details = _cache(store, (_) async => {'value': 'detail'});
    final request = feeds.refresh(1);
    await store.started.future;
    final clearing = RepositoryCache.invalidateAll([feeds, details]);
    expect(feeds.cached(1), isNull);
    store.release.complete();
    await request;
    await clearing;
    expect(store.clears, 1);
    expect(await feeds.restore(1), isNull);
  });

  test('invalidating a pending disk read does not start an obsolete fetch',
      () async {
    final store = _DelayedReadStore();
    var fetches = 0;
    final cache = _cache(store, (_) async {
      fetches++;
      return {'value': 'previous account'};
    });
    final request = cache.load(1);
    final rejected = expectLater(request, throwsStateError);
    await store.started.future;
    await cache.invalidate();
    store.release.complete();
    await rejected;
    expect(fetches, 0);
    expect(cache.cached(1), isNull);
  });
}

RepositoryCache<int, String> _cache(LocalCacheStore store,
        Future<Map<String, dynamic>> Function(int) fetch) =>
    RepositoryCache(
      fetch: fetch,
      decode: (json, _) => json['value'] as String,
      keyOf: (key) => '$key',
      tier: CacheTier.shortLived,
      store: store,
      scope: LocalCacheScopes.postDrafts,
    );

class _DelayedWriteStore extends MemoryLocalCacheStore {
  final started = Completer<void>();
  final release = Completer<void>();
  var clears = 0;
  @override
  Future<void> write(String key, Object payload,
      {String scope = LocalCacheScopes.global, int schemaVersion = 1}) async {
    started.complete();
    await release.future;
    await super.write(key, payload, scope: scope, schemaVersion: schemaVersion);
  }

  @override
  Future<void> clearScope(String scope) async {
    clears++;
    await super.clearScope(scope);
  }
}

class _DelayedReadStore extends MemoryLocalCacheStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<LocalCacheRecord?> read(String key,
      {String scope = LocalCacheScopes.global, int schemaVersion = 1}) async {
    started.complete();
    await release.future;
    return super.read(key, scope: scope, schemaVersion: schemaVersion);
  }
}
