import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/teams/api/api_following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

/// Real API provider kept separate from the catalogue-backed `teamRepository`.
/// The session-aware client injects the latest login token for every request.
final FollowingTeamsRepository followingTeamsRepository =
    ApiFollowingTeamsRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
