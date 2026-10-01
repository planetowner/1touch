import 'package:onetouch/models/player_detail.dart';

abstract interface class PlayerDetailRepository {
  Future<PlayerDetail> load(int playerId, {int? seasonId});
  Future<List<PlayerCandidate>> search(String query);
}

class PlayerDetailSnapshot {
  const PlayerDetailSnapshot(this.data, this.savedAt);

  final PlayerDetail data;
  final DateTime savedAt;
}

abstract interface class CachedPlayerDetailRepository
    implements PlayerDetailRepository {
  PlayerDetailSnapshot? snapshotFor(int playerId, {int? seasonId});

  Future<PlayerDetailSnapshot?> restoreFor(int playerId, {int? seasonId});
}
