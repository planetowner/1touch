import 'package:flutter/foundation.dart';
import 'package:onetouch/models/player.dart';

abstract interface class PlayerRepository {
  List<Player> get allPlayers;

  Player? findById(String id);

  List<Player> search(String query);

  List<Player> byLeague(String leagueName);

  List<Player> byPosition(PlayerPosition position);

  List<Player> get favorites;

  ValueListenable<List<String>> get followedPlayerIds;

  bool isFollowing(String playerId);

  Future<void> initializeFollowing();

  Future<void> updateFollowing(Iterable<String> playerIds);

  Future<bool> toggleFollowing(String playerId);

  List<Player> get onesToWatch;

  List<Player> get ranking;

  List<PlayerMatchSummary> recentMatchesFor(String playerId);
}
