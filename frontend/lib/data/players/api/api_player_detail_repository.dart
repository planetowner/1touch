import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/models/player_detail.dart';

class ApiPlayerDetailRepository implements PlayerDetailRepository {
  ApiPlayerDetailRepository(
      {required this.client, required this.baseUri, required this.headers});
  final http.Client client;
  final Uri baseUri;
  final Map<String, String> headers;

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final uri = baseUri
        .resolve(path)
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await client
        .get(uri, headers: {'Accept': 'application/json', ...headers});
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Player detail request failed (${response.statusCode}).', uri);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    final detail = playerDetailFromJson(await _get('players/$playerId/detail', {
      if (seasonId != null) 'season_id': '$seasonId',
    }));
    if (detail.playerId != playerId ||
        (seasonId != null && detail.selectedSeason?.id != seasonId)) {
      throw const FormatException('Player detail identity mismatch.');
    }
    return detail;
  }

  @override
  Future<List<PlayerCandidate>> search(String query) async {
    final json = await _get('players/comparison-candidates', {'q': query});
    return (json['players'] as List)
        .map((r) => (
              id: r['player_id'] as int,
              name: r['name'] as String,
              image: r['image'] as String?
            ))
        .toList();
  }
}
