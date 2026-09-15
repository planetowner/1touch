import 'package:flutter/foundation.dart';
import 'package:onetouch/models/following_player.dart';

abstract interface class FollowingPlayersRepository {
  /// Last authoritative, backend-ordered list loaded by this repository.
  ValueListenable<List<FollowingPlayer>> get cachedPlayers;

  Future<List<FollowingPlayer>> load();

  /// Replaces the complete ordered list and returns the backend's authoritative
  /// list after the update succeeds.
  Future<List<FollowingPlayer>> replaceFollowing(
    Iterable<int> playerIds,
  );
}
