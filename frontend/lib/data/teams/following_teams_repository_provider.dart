import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/teams/api/api_following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';

/// Real API provider kept separate from the catalogue-backed `teamRepository`.
///
/// The current API configuration captures the development session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final FollowingTeamsRepository followingTeamsRepository =
    ApiFollowingTeamsRepository(
  api: apiClient,
);
