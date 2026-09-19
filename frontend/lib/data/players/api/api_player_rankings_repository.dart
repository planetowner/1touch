import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/players/api/api_player_rankings_mapper.dart';
import 'package:onetouch/data/players/api/api_player_rankings_response.dart';
import 'package:onetouch/data/players/player_rankings_repository.dart';
import 'package:onetouch/models/player_rankings.dart';

/// HTTP implementation of `GET /v1/players/rankings`.
class ApiPlayerRankingsRepository implements PlayerRankingsRepository {
  ApiPlayerRankingsRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

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

    final uri = _apiBaseUri.resolve('players/rankings').replace(
      queryParameters: {
        'season_id': '$seasonId',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Player rankings request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the player-rankings response to be a JSON object.',
      );
    }
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
