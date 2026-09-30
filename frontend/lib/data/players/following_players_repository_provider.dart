import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/players/api/api_following_players_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The current API configuration captures the environment session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final ApiFollowingPlayersRepository followingPlayersRepository =
    ApiFollowingPlayersRepository(
  api: apiClient,
  cacheStore: localCacheStore,
);
