import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_following_players_mapper.dart';
import 'package:onetouch/data/players/api/api_following_players_response.dart';
import 'package:onetouch/data/players/following_players_repository.dart';
import 'package:onetouch/models/following_player.dart';

/// HTTP implementation of the current user's ordered followed-player list.
class ApiFollowingPlayersRepository implements FollowingPlayersRepository {
  ApiFollowingPlayersRepository({required ApiClient api}) : _api = api;

  static const int maxFollowingPlayers = 1000;

  final ApiClient _api;
  final ValueNotifier<List<FollowingPlayer>> _cachedPlayers =
      ValueNotifier(const []);

  @override
  ValueListenable<List<FollowingPlayer>> get cachedPlayers => _cachedPlayers;

  @override
  Future<List<FollowingPlayer>> load() => _fetchAndCache();

  @override
  Future<List<FollowingPlayer>> replaceFollowing(
    Iterable<int> playerIds,
  ) async {
    final ids = List<int>.unmodifiable(playerIds);
    _validatePlayerIds(ids);

    final uri = _api.baseUri.resolve('users/me/following/players');
    final response = await _api.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'player_ids': ids}),
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final update = ApiFollowingPlayersUpdateResponse.fromJson(decoded);
    if (!update.ok) {
      throw const FormatException(
        'Expected the following-players update to return ok=true.',
      );
    }

    // PUT returns only {"ok": true}; re-fetch names, images, and canonical
    // ordering instead of manufacturing a partial local response.
    return _fetchAndCache();
  }

  Future<List<FollowingPlayer>> _fetchAndCache() async {
    final uri = _api.baseUri.resolve('users/me/following/players');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final apiResponse = ApiFollowingPlayersResponse.fromJson(decoded);
    final players = List<FollowingPlayer>.unmodifiable(
      apiResponse.items.map(followingPlayerFromApiResponse),
    );
    final ids = players.map((player) => player.playerId).toList();
    if (ids.length != ids.toSet().length) {
      throw const FormatException(
        'Expected unique player IDs in the following-players response.',
      );
    }

    _cachedPlayers.value = players;
    return players;
  }

  static void _validatePlayerIds(List<int> ids) {
    if (ids.length > maxFollowingPlayers) {
      throw RangeError.range(
        ids.length,
        0,
        maxFollowingPlayers,
        'playerIds.length',
      );
    }
    for (final id in ids) {
      if (id < 1) {
        throw RangeError.value(id, 'playerIds', 'IDs must be positive');
      }
    }
    if (ids.length != ids.toSet().length) {
      throw ArgumentError.value(
        ids,
        'playerIds',
        'IDs must not be repeated',
      );
    }
  }
}
