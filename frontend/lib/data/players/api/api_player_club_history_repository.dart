import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/players/api/api_player_club_history_mapper.dart';
import 'package:onetouch/data/players/api/api_player_club_history_response.dart';
import 'package:onetouch/data/players/player_club_history_repository.dart';
import 'package:onetouch/models/player_club_history.dart';

/// HTTP implementation of `GET /v1/players/{player_id}/club-history`.
class ApiPlayerClubHistoryRepository implements PlayerClubHistoryRepository {
  ApiPlayerClubHistoryRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
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

    final uri = _apiBaseUri.resolve('players/$playerId/club-history');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Player club-history request failed with status '
        '${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the player club-history response to be a JSON object.',
      );
    }
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
