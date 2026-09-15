import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/players/api/api_following_players_mapper.dart';
import 'package:onetouch/data/players/api/api_following_players_response.dart';
import 'package:onetouch/data/players/following_players_repository.dart';
import 'package:onetouch/models/following_player.dart';

/// HTTP implementation of the current user's ordered followed-player list.
class ApiFollowingPlayersRepository implements FollowingPlayersRepository {
  ApiFollowingPlayersRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  static const int maxFollowingPlayers = 1000;

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
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

    final uri = _apiBaseUri.resolve('users/me/following/players');
    final response = await _client.put(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ..._requestHeaders,
      },
      body: jsonEncode({'player_ids': ids}),
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Following-players update failed with status '
        '${response.statusCode}.',
        uri,
      );
    }

    final decoded = _decodeObject(
      response.body,
      responseName: 'following-players update',
    );
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
    final uri = _apiBaseUri.resolve('users/me/following/players');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Following-players request failed with status '
        '${response.statusCode}.',
        uri,
      );
    }

    final decoded = _decodeObject(
      response.body,
      responseName: 'following-players',
    );
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

  static Map<String, dynamic> _decodeObject(
    String body, {
    required String responseName,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected the $responseName response to be a JSON object.',
      );
    }
    return decoded;
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
