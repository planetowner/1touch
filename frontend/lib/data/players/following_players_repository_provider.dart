import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/players/api/api_following_players_repository.dart';
import 'package:onetouch/data/players/following_players_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The current API configuration captures the environment session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final FollowingPlayersRepository followingPlayersRepository =
    ApiFollowingPlayersRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
