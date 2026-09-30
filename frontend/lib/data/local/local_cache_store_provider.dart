import 'local_cache_store.dart';
import 'sqlite_local_cache_store.dart';

final LocalCacheStore localCacheStore = SqliteLocalCacheStore();

Future<void> clearAuthenticatedLocalCache() =>
    localCacheStore.clearScope(LocalCacheScopes.authenticatedUser);
