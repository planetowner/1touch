import 'dart:async';

import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/players/following_players_repository_provider.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/models/team.dart';

class SessionDataSnapshot {
  const SessionDataSnapshot({
    required this.account,
    this.followingTeams,
    this.followingPlayers,
  });

  final ApiCurrentUserResponse account;
  final List<Team>? followingTeams;
  final List<FollowingPlayer>? followingPlayers;

  bool get profileComplete => [
        account.username,
        account.firstName,
        account.lastName
      ].every((value) => value != null && value.isNotEmpty);

  bool get canOpenHome {
    final favoriteTeamId = account.favoriteTeamId;
    final teams = followingTeams;
    return profileComplete &&
        account.onboardingComplete &&
        favoriteTeamId != null &&
        teams != null &&
        followingPlayers != null &&
        teams.any((team) => team.teamId == favoriteTeamId);
  }
}

/// Coordinates the local-first session resources and their conventional
/// synchronization triggers. UI reads the hydrated controllers while network
/// responses are persisted by each repository before being published.
class SessionDataSynchronizer {
  Future<SessionDataSnapshot?> hydrate() async {
    await footballCatalog.initialize();
    final account = await currentUserRepository.loadCachedAccount();
    if (account == null) return null;

    final results = await Future.wait<Object?>([
      followingTeamsRepository.restoreCached(),
      followingPlayersRepository.restoreCached(),
    ]);
    final teams = results[0] as List<Team>?;
    final players = results[1] as List<FollowingPlayer>?;
    if (players != null) playerFollowingController.applyAuthoritative(players);
    final snapshot = SessionDataSnapshot(
      account: account,
      followingTeams: teams,
      followingPlayers: players,
    );
    _apply(snapshot);
    return snapshot;
  }

  Future<SessionDataSnapshot> synchronize({
    required CacheSyncTrigger trigger,
  }) =>
      _synchronize(trigger);

  Future<SessionDataSnapshot> _synchronize(CacheSyncTrigger trigger) async {
    await footballCatalog.initialize();
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.staticData,
      trigger: trigger,
      savedAt: footballCatalog.savedAt,
    )) {
      if (trigger == CacheSyncTrigger.userRefresh) {
        // Pull-to-refresh is the explicit force-refresh path, so wait for it.
        await footballCatalog.refresh(trigger: trigger);
      } else {
        // Reference-data failure must not prevent fresh personal data from
        // replacing its cached snapshot during passive synchronization.
        unawaited(_refreshCatalogInBackground(trigger));
      }
    }

    final cachedAccount = await currentUserRepository.loadCachedAccount();
    final shouldRefreshUserData = AppCachePolicy.shouldRefresh(
      tier: CacheTier.userData,
      trigger: trigger,
      savedAt: cachedAccount == null ? null : DateTime.now().toUtc(),
    );
    if (!shouldRefreshUserData && cachedAccount != null) {
      final cachedTeams = await followingTeamsRepository.restoreCached();
      final cachedPlayers = await followingPlayersRepository.restoreCached();
      final snapshot = SessionDataSnapshot(
        account: cachedAccount,
        followingTeams: cachedTeams,
        followingPlayers: cachedPlayers,
      );
      if (cachedPlayers != null) {
        playerFollowingController.applyAuthoritative(cachedPlayers);
      }
      _apply(snapshot);
      return snapshot;
    }

    final account = await currentUserRepository.loadAccount();
    if (![account.username, account.firstName, account.lastName]
            .every((value) => value != null && value.isNotEmpty) ||
        !account.onboardingComplete) {
      return SessionDataSnapshot(account: account);
    }

    final results = await Future.wait<Object>([
      followingTeamsRepository.load(),
      followingPlayersRepository.load(),
    ]);
    final snapshot = SessionDataSnapshot(
      account: account,
      followingTeams: results[0] as List<Team>,
      followingPlayers: results[1] as List<FollowingPlayer>,
    );
    playerFollowingController.applyAuthoritative(snapshot.followingPlayers!);
    _apply(snapshot);
    return snapshot;
  }

  Future<void> _refreshCatalogInBackground(CacheSyncTrigger trigger) async {
    try {
      await footballCatalog.refresh(trigger: trigger);
    } on Object {
      // The stale catalog remains usable when a background refresh fails.
    }
  }

  void _apply(SessionDataSnapshot snapshot) {
    if (!snapshot.canOpenHome) return;
    currentUserPreferences.applyServerSelection(
      UserTeamPreferences(
        favoriteTeamId: snapshot.account.favoriteTeamId!,
        followedTeamIds:
            snapshot.followingTeams!.map((team) => team.teamId).toList(),
      ),
    );
  }
}

final sessionDataSynchronizer = SessionDataSynchronizer();
