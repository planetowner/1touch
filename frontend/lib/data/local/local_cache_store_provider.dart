import 'package:flutter/foundation.dart';

import 'local_cache_store.dart';
import 'sqlite_local_cache_store.dart';

final LocalCacheStore _sqliteLocalCacheStore = SqliteLocalCacheStore();
LocalCacheStore? _testLocalCacheStore;

LocalCacheStore get localCacheStore =>
    _testLocalCacheStore ?? _sqliteLocalCacheStore;

/// Must be called before a global repository first reads [localCacheStore].
@visibleForTesting
void setLocalCacheStoreForTesting(LocalCacheStore? store) {
  _testLocalCacheStore = store;
}

Future<void> clearAuthenticatedLocalCache() =>
    localCacheStore.clearScope(LocalCacheScopes.authenticatedUser);
