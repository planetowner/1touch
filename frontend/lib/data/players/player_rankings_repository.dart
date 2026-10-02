import 'package:flutter/foundation.dart';
import 'package:onetouch/models/player_rankings.dart';

typedef PlayerRankingsQuery = ({int seasonId, int limit, int offset});

abstract interface class PlayerRankingsRepository {
  ValueListenable<Map<PlayerRankingsQuery, PlayerRankingsPage>> get cachedPages;

  PlayerRankingsPage? cachedFor({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  });

  Future<PlayerRankingsPage> load({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  });

  Future<PlayerRankingsPage> refresh({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  });
}
