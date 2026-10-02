import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart';
import 'package:onetouch/data/players/following_players_repository_provider.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

/// Removes all account-bound snapshots before logout or account replacement.
Future<void> clearSessionData() async {
  await clearAuthenticatedLocalCache();
  await invalidateCommunityPostCache();
  followingTeamsRepository.clearMemory();
  followingPlayersRepository.clearMemory();
  playerFollowingController.clear();
  currentUserPreferences.clearSessionState();
}
