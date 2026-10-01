import 'package:onetouch/models/player_detail.dart';

abstract interface class PlayerDetailRepository {
  Future<PlayerDetail> load(int playerId, {int? seasonId});
  Future<List<PlayerCandidate>> search(String query);
  Future<PlayerComparisonPage> comparisonCandidates(String query,
      {String? position, int? excludedId, int limit = 20, int offset = 0});
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
