import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_club_history_mapper.dart';
import 'package:onetouch/data/players/api/api_player_club_history_response.dart';
import 'package:onetouch/data/players/player_club_history_repository.dart';
import 'package:onetouch/models/player_club_history.dart';

/// HTTP implementation of `GET /v1/players/{player_id}/club-history`.
class ApiPlayerClubHistoryRepository implements PlayerClubHistoryRepository {
  ApiPlayerClubHistoryRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final ValueNotifier<Map<int, PlayerClubHistory>> _cachedHistories =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, PlayerClubHistory>> get cachedHistories =>
      _cachedHistories;

  @override
  PlayerClubHistory? cachedForPlayer(int playerId) =>
      _cachedHistories.value[playerId];

  @override
  Future<PlayerClubHistory> loadForPlayer(int playerId) async {
    if (playerId < 1) {
      throw RangeError.value(playerId, 'playerId', 'Must be positive');
    }
    final cached = cachedForPlayer(playerId);
    if (cached != null) return cached;

    final uri = _api.baseUri.resolve('players/$playerId/club-history');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final history = playerClubHistoryFromApiResponse(
      ApiPlayerClubHistoryResponse.fromJson(decoded),
    );
    if (history.playerId != playerId) {
      throw FormatException(
        'Expected player_id $playerId but received ${history.playerId}.',
      );
    }

    _cachedHistories.value = Map.unmodifiable({
      ..._cachedHistories.value,
      playerId: history,
    });
    return history;
  }
}
