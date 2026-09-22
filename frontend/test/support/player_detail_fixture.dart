import 'dart:convert';
import 'dart:io';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/models/player_detail.dart';

Map<String, dynamic> playerDetailJson(
    {int playerId = 9967153,
    String position = 'FW',
    int? seasonId,
    String? playerImage}) {
  final json =
      jsonDecode(File('test/fixtures/player_detail.json').readAsStringSync())
          as Map<String, dynamic>;
  json['player_id'] = playerId;
  json['profile']['name'] = 'Player $playerId';
  json['profile']['image'] = playerImage;
  json['profile']['position_group'] = position;
  json['current_position'] = position;
  json['analysis']['position_group'] = position;
  if (seasonId != null) {
    json['selected_season'] =
        (json['seasons'] as List).firstWhere((s) => s['season_id'] == seasonId);
    json['matches'] = (json['matches'] as List).take(1).toList();
  }
  return json;
}

PlayerDetail detailFixture(
        {int playerId = 9967153,
        String position = 'FW',
        int? seasonId,
        String? playerImage}) =>
    playerDetailFromJson(playerDetailJson(
        playerId: playerId,
        position: position,
        seasonId: seasonId,
        playerImage: playerImage));

class FakePlayerDetailRepository implements PlayerDetailRepository {
  final calls = <({int playerId, int? seasonId})>[];
  final searchQueries = <String>[];
  bool fail = false;
  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    calls.add((playerId: playerId, seasonId: seasonId));
    if (fail) throw StateError('Test failure');
    return detailFixture(
        playerId: playerId,
        seasonId: seasonId,
        position: playerId == 2 ? 'GK' : 'FW');
  }

  @override
  Future<List<PlayerCandidate>> search(String query) async {
    searchQueries.add(query);
    final normalized = query.trim().toLowerCase();
    return [
      for (final id in [1, 2, 3])
        if (normalized.isEmpty || 'player $id'.contains(normalized))
          (id: id, name: 'Player $id', image: null),
    ];
  }
}
