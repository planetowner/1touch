import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/models/player_detail.dart';

class ApiPlayerDetailRepository implements PlayerDetailRepository {
  ApiPlayerDetailRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final uri = _api.baseUri
        .resolve(path)
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _api.get(uri);
    return _api.decodeJson<Map<String, dynamic>>(response);
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
    return (json['players'] as List).cast<Map<String, dynamic>>().map(playerCandidateFromJson).toList();
  }
}
