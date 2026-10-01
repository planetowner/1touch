import 'dart:convert';
import 'dart:io';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/models/player_detail.dart';

Map<String, dynamic> playerDetailJson(
    {int playerId = 9967153,
    String position = 'FW',
    int? seasonId,
    String? playerImage,
    bool duplicateFirstClub = false}) {
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
  if (duplicateFirstClub) {
    final clubs = json['clubs'] as List;
    clubs.add(Map<String, dynamic>.from(clubs.first as Map));
  }
  return json;
}

PlayerDetail detailFixture(
        {int playerId = 9967153,
        String position = 'FW',
        int? seasonId,
        String? playerImage,
        bool duplicateFirstClub = false}) =>
    playerDetailFromJson(playerDetailJson(
        playerId: playerId,
        position: position,
        seasonId: seasonId,
        playerImage: playerImage,
        duplicateFirstClub: duplicateFirstClub));

class FakePlayerDetailRepository implements PlayerDetailRepository {
  FakePlayerDetailRepository({this.duplicateFirstClub = false});

  final bool duplicateFirstClub;
  final calls = <({int playerId, int? seasonId})>[];
  final searchQueries = <String>[];
  final comparisonQueries = <({
    String query,
    String? position,
    int? excludedId,
    int limit,
    int offset
  })>[];
  bool fail = false;
  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    calls.add((playerId: playerId, seasonId: seasonId));
    if (fail) throw StateError('Test failure');
    return detailFixture(
        playerId: playerId,
        seasonId: seasonId,
        position: playerId == 2 ? 'GK' : 'FW',
        duplicateFirstClub: duplicateFirstClub);
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

  @override
  Future<PlayerComparisonPage> comparisonCandidates(String query,
      {String? position,
      int? excludedId,
      int limit = 20,
      int offset = 0}) async {
    comparisonQueries.add((
      query: query,
      position: position,
      excludedId: excludedId,
      limit: limit,
      offset: offset
    ));
    final candidates = await search(query);
    final players = candidates
        .map((player) {
          final detail = detailFixture(
              playerId: player.id, position: player.id == 2 ? 'GK' : 'FW');
          return PlayerComparisonCandidate(
            player: player,
            position: detail.analysis?.position,
            teamId: detail.profile.teamId,
            teamName: detail.profile.teamName,
            jerseyNumber: detail.profile.jerseyNumber,
          );
        })
        .where((candidate) =>
            candidate.player.id != excludedId &&
            (position == null || candidate.position == position))
        .toList();
    return PlayerComparisonPage(
      players: players.skip(offset).take(limit).toList(),
      seasonName: '2026/2027',
      total: players.length,
      limit: limit,
      offset: offset,
    );
  }
}
