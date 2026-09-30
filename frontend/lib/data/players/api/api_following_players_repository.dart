import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_following_players_mapper.dart';
import 'package:onetouch/data/players/api/api_following_players_response.dart';
import 'package:onetouch/data/players/following_players_repository.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/data/local/local_cache_store.dart';

/// HTTP implementation of the current user's ordered followed-player list.
class ApiFollowingPlayersRepository implements FollowingPlayersRepository {
  ApiFollowingPlayersRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  static const int maxFollowingPlayers = 1000;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final ValueNotifier<List<FollowingPlayer>> _cachedPlayers =
      ValueNotifier(const []);

  @override
  ValueListenable<List<FollowingPlayer>> get cachedPlayers => _cachedPlayers;

  @override
  Future<List<FollowingPlayer>> load() => _fetchAndCache();

  Future<List<FollowingPlayer>?> restoreCached() async {
    final record = await _cacheStore?.read(
      LocalCacheKeys.followingPlayers,
      scope: LocalCacheScopes.authenticatedUser,
    );
    if (record == null) return null;
    try {
      final players = _parsePlayers(record.payload);
      _cachedPlayers.value = players;
      return players;
    } on Object {
      await _cacheStore?.delete(
        LocalCacheKeys.followingPlayers,
        scope: LocalCacheScopes.authenticatedUser,
      );
      return null;
    }
  }

  void clearMemory() => _cachedPlayers.value = const [];

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
    final players = _parsePlayers(decoded);
    await _cacheStore?.write(
      LocalCacheKeys.followingPlayers,
      decoded,
      scope: LocalCacheScopes.authenticatedUser,
    );
    _cachedPlayers.value = players;
    return players;
  }

  List<FollowingPlayer> _parsePlayers(Object decoded) {
    if (decoded is! Map) {
      throw const FormatException(
        'Expected following players to be a JSON object.',
      );
    }
    final apiResponse = ApiFollowingPlayersResponse.fromJson(
      decoded.cast<String, dynamic>(),
    );
    final players = List<FollowingPlayer>.unmodifiable(
      apiResponse.items.map(followingPlayerFromApiResponse),
    );
    final ids = players.map((player) => player.playerId).toList();
    if (ids.length != ids.toSet().length) {
      throw const FormatException(
        'Expected unique player IDs in the following-players response.',
      );
    }

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
