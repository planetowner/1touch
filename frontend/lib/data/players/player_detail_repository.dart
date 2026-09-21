import 'package:onetouch/models/player_detail.dart';

abstract interface class PlayerDetailRepository {
  Future<PlayerDetail> load(int playerId, {int? seasonId});
  Future<List<PlayerCandidate>> search(String query);
}
