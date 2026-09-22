import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/players/api/api_following_players_repository.dart';
import 'package:onetouch/data/players/following_players_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The session-aware client injects the latest login token for every request.
final FollowingPlayersRepository followingPlayersRepository =
    ApiFollowingPlayersRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
