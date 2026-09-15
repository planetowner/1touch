import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/teams/api/api_following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Real API provider kept separate from the catalogue-backed `teamRepository`.
///
/// The current API configuration captures the development session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final FollowingTeamsRepository followingTeamsRepository =
    ApiFollowingTeamsRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
