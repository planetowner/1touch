import 'package:onetouch/models/player.dart';

abstract interface class PlayerRepository {
  List<Player> get allPlayers;

  Player? findById(String id);

  List<Player> search(String query);

  List<Player> byLeague(String leagueName);

  List<Player> byPosition(PlayerPosition position);

  List<Player> get favorites;

  List<Player> get onesToWatch;

  List<Player> get ranking;

  List<PlayerMatchSummary> recentMatchesFor(String playerId);
}
