import 'package:onetouch/models/player_rankings.dart';

abstract interface class PlayerRankingsRepository {
  Future<PlayerRankingsPage> load({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  });
}
