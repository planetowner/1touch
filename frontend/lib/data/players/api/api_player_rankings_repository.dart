import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_rankings_mapper.dart';
import 'package:onetouch/data/players/api/api_player_rankings_response.dart';
import 'package:onetouch/data/players/player_rankings_repository.dart';
import 'package:onetouch/models/player_rankings.dart';

/// HTTP implementation of `GET /v1/players/rankings`.
class ApiPlayerRankingsRepository implements PlayerRankingsRepository {
  ApiPlayerRankingsRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<PlayerRankingsPage> load({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (seasonId < 1) {
      throw RangeError.value(seasonId, 'seasonId', 'Must be positive');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }

    final uri = _api.baseUri.resolve('players/rankings').replace(
      queryParameters: {
        'season_id': '$seasonId',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final rankings = playerRankingsFromApiResponse(
      ApiPlayerRankingsResponse.fromJson(decoded),
    );
    if (rankings.seasonId != seasonId ||
        rankings.limit != limit ||
        rankings.offset != offset) {
      throw const FormatException(
        'Player-ranking response does not match the requested page.',
      );
    }
    return rankings;
  }
}
