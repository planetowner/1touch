import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/players/api/api_player_indicators_response.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/models/player_indicators.dart';

class ApiPlayerIndicatorsRepository implements PlayerIndicatorsRepository {
  ApiPlayerIndicatorsRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = apiBaseUri.toString().endsWith('/')
            ? apiBaseUri
            : Uri.parse('$apiBaseUri/'),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<PlayerIndicators?> loadCurrent(int playerId) async {
    if (playerId < 1) throw RangeError.value(playerId, 'playerId');
    final uri = _apiBaseUri.resolve('players/$playerId/indicators');
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', ..._requestHeaders},
    );
    // 현재 시즌 명단에 없는 선수에게 과거 시즌 등급을 대신 보여주지 않아요.
    if (response.statusCode == 404) {
      final error = jsonDecode(response.body);
      if (error is Map<String, dynamic> &&
          error['detail'] == 'Player not in a current five-league squad') {
        return null;
      }
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Player indicators request failed with status ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a player indicators object.');
    }
    final result = ApiPlayerIndicatorsResponse.fromJson(decoded).indicators;
    if (result.playerId != playerId) {
      throw const FormatException('Player indicator identity mismatch.');
    }
    return result;
  }
}
