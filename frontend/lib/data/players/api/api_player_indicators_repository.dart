import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_indicators_response.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/models/player_indicators.dart';

class ApiPlayerIndicatorsRepository implements PlayerIndicatorsRepository {
  ApiPlayerIndicatorsRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<PlayerIndicators?> loadCurrent(int playerId) async {
    if (playerId < 1) throw RangeError.value(playerId, 'playerId');
    final uri = _api.baseUri.resolve('players/$playerId/indicators');
    final response = await _api.get(
      uri,
    );
    // 현재 시즌 명단에 없는 선수에게 과거 시즌 등급을 대신 보여주지 않아요.
    if (response.statusCode == 404) {
      final error = jsonDecode(response.body);
      if (error is Map<String, dynamic> &&
          error['detail'] == 'Player not in a current five-league squad') {
        return null;
      }
    }
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final result = ApiPlayerIndicatorsResponse.fromJson(decoded).indicators;
    if (result.playerId != playerId) {
      throw const FormatException('Player indicator identity mismatch.');
    }
    return result;
  }
}
