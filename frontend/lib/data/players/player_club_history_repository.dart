import 'package:flutter/foundation.dart';
import 'package:onetouch/models/player_club_history.dart';

abstract interface class PlayerClubHistoryRepository {
  ValueListenable<Map<int, PlayerClubHistory>> get cachedHistories;

  PlayerClubHistory? cachedForPlayer(int playerId);

  Future<PlayerClubHistory> loadForPlayer(int playerId);
}
