import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';

// 저장소마다 데이터 변환과 키만 정하고, 복원·갱신·요청 공유는 같은 규칙을 써요.
class RepositoryCache<K, V extends Object> {
  RepositoryCache({
    required this.fetch,
    required this.decode,
    required this.keyOf,
    required this.tier,
    this.store,
    this.scope = LocalCacheScopes.global,
  });

  final Future<Map<String, dynamic>> Function(K) fetch;
  final V Function(Map<String, dynamic>, K) decode;
  final String Function(K) keyOf;
  final CacheTier tier;
  final LocalCacheStore? store;
  final String scope;
  final ValueNotifier<Map<K, V>> _values =
      ValueNotifier(Map<K, V>.unmodifiable({}));
  ValueListenable<Map<K, V>> get values => _values;
  final Map<K, DateTime> _savedAt = {};
  final Map<K, Future<V>> _loads = {};
  final Map<K, Future<V>> _fetches = {};
  final Set<Future<void>> _writes = {};
  int _generation = 0;

  V? cached(K key) => _values.value[key];

  Future<V> load(K key, {bool forceRefresh = false}) {
    if (forceRefresh) return refresh(key);
    final value = cached(key);
    if (value != null) {
      _refreshIfStale(key);
      return Future.value(value);
    }
    final pending = _loads[key];
    if (pending != null) return pending;
    late final Future<V> load;
    load = _restoreOrFetch(key).whenComplete(() {
      if (identical(_loads[key], load)) _loads.remove(key);
    });
    _loads[key] = load;
    return load;
  }

  Future<V> _restoreOrFetch(K key) async {
    final generation = _generation;
    final restored = await restore(key);
    if (restored != null) {
      _refreshIfStale(key);
      return restored;
    }
    // 로그아웃이나 변경으로 폐기한 조회를 새 요청으로 이어가지 않아요.
    if (generation != _generation) {
      throw StateError('Cache was invalidated during restoration.');
    }
    return refresh(key);
  }

  // 앱 시작 시 디스크만 읽는 경로도 같은 복원 규칙을 사용해요.
  Future<V?> restore(K key) async {
    final existing = cached(key);
    if (existing != null) return existing;
    final generation = _generation;
    try {
      final record = await store?.read(keyOf(key), scope: scope);
      if (generation != _generation) return null;
      final current = cached(key);
      if (current != null) return current;
      if (record == null) return null;
      try {
        final value =
            decode(Map<String, dynamic>.from(record.payload as Map), key);
        _publish(key, value, record.savedAt);
        return value;
      } on Object {
        await store?.delete(keyOf(key), scope: scope);
      }
    } on Object {
      // 기기 캐시를 읽지 못해도 서버에서 데이터를 불러올 수 있어요.
    }
    return null;
  }

  void _refreshIfStale(K key) {
    if (AppCachePolicy.shouldRefresh(
        tier: tier,
        trigger: CacheSyncTrigger.screenEnter,
        savedAt: _savedAt[key])) {
      unawaited(refresh(key).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<V> refresh(K key) {
    final pending = _fetches[key];
    if (pending != null) return pending;
    late final Future<V> request;
    request = _fetchAndCache(key).whenComplete(() {
      if (identical(_fetches[key], request)) _fetches.remove(key);
    });
    _fetches[key] = request;
    return request;
  }

  Future<V> _fetchAndCache(K key) async {
    final generation = _generation;
    final payload = await fetch(key);
    final value = decode(payload, key);
    if (generation == _generation) {
      _publish(key, value, clock.now().toUtc());
      await _write(key, payload);
    }
    return value;
  }

  void _publish(K key, V value, DateTime savedAt) {
    _savedAt[key] = savedAt;
    _values.value = Map.unmodifiable({..._values.value, key: value});
  }

  Future<void> _write(K key, Map<String, dynamic> payload) async {
    final cacheStore = store;
    if (cacheStore == null) return;
    Future<void>? write;
    try {
      write = cacheStore.write(keyOf(key), payload, scope: scope);
      _writes.add(write);
      await write;
    } on Object {
      // 캐시 저장 실패로 정상 서버 응답까지 실패 처리하지 않아요.
    } finally {
      _writes.remove(write);
    }
  }

  Future<void> remove(K key) async {
    _savedAt.remove(key);
    _values.value = Map.unmodifiable({..._values.value}..remove(key));
    try {
      await store?.delete(keyOf(key), scope: scope);
    } on Object {
      // 서버에서 더 이상 제공하지 않는 데이터는 메모리에서도 제거해요.
    }
  }

  Future<void> invalidate() => invalidateAll([this]);

  void _clearMemory() {
    _generation++;
    _loads.clear();
    _fetches.clear();
    _savedAt.clear();
    _values.value = Map<K, V>.unmodifiable({});
  }

  static Future<void> invalidateAll(Iterable<RepositoryCache> caches) async {
    final writes = <Future<void>>[];
    final scopes = <(LocalCacheStore, String)>{};
    for (final cache in caches) {
      cache._clearMemory();
      writes.addAll(cache._writes);
      if (cache.store case final store?) scopes.add((store, cache.scope));
    }
    // 진행 중이던 저장을 마친 뒤 지워야 이전 계정 데이터가 다시 남지 않아요.
    await Future.wait(writes.map((write) async {
      try {
        await write;
      } on Object {
        // 한 번의 저장 실패가 나머지 캐시 정리를 막지 않아요.
      }
    }));
    for (final (store, scope) in scopes) {
      try {
        await store.clearScope(scope);
      } on Object {
        // 캐시 정리 실패로 이미 완료한 서버 변경을 실패 처리하지 않아요.
      }
    }
  }
}
