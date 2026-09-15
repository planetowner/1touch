import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/teams/api/api_following_teams_response.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/models/team.dart';

class ApiFollowingTeamsRepository implements FollowingTeamsRepository {
  ApiFollowingTeamsRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  static const int maxFollowingTeams = 5;

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<List<Team>> _cachedTeams = ValueNotifier(const []);

  @override
  ValueListenable<List<Team>> get cachedTeams => _cachedTeams;

  @override
  Future<List<Team>> load() => _fetchAndCache();

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) async {
    final ids = List<int>.unmodifiable(teamIds);
    _validateSelection(ids, favoriteTeamId);

    final uri = _apiBaseUri.resolve('users/me/following/teams');
    final response = await _client.put(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ..._requestHeaders,
      },
      body: jsonEncode({
        'teamIds': ids,
        'favoriteTeamId': favoriteTeamId,
      }),
    );
    if (response.statusCode == 409) {
      throw _cooldownException(response.body);
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Following-teams update failed with status ${response.statusCode}.',
        uri,
      );
    }

    final update = ApiFollowingTeamsUpdateResponse.fromJson(
      _decodeObject(response.body, responseName: 'following-teams update'),
    );
    if (!update.ok) {
      throw const FormatException(
        'Expected the following-teams update to return ok=true.',
      );
    }

    // PUT returns no team objects, so re-fetch the canonical ordered list.
    return _fetchAndCache();
  }

  Future<List<Team>> _fetchAndCache() async {
    final uri = _apiBaseUri.resolve('users/me/following/teams');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Following-teams request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Expected the following-teams response to be a JSON list.',
      );
    }
    final teams = List<Team>.unmodifiable(
      decoded.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected each following-teams item to be an object.',
          );
        }
        return teamFromApiResponse(ApiTeamResponse.fromJson(item));
      }),
    );
    final ids = teams.map((team) => team.teamId).toList();
    if (ids.any((id) => id < 1) || ids.length != ids.toSet().length) {
      throw const FormatException(
        'Expected unique positive team IDs in the following-teams response.',
      );
    }

    _cachedTeams.value = teams;
    return teams;
  }

  static FavoriteTeamCooldownException _cooldownException(String body) {
    final response = ApiFavoriteTeamCooldownResponse.fromJson(
      _decodeObject(body, responseName: 'favorite-team cooldown'),
    );
    final availableAt = DateTime.tryParse(response.availableAt)?.toUtc();
    if (availableAt == null) {
      throw const FormatException(
        'Expected a valid favorite-team cooldown available_at timestamp.',
      );
    }
    return FavoriteTeamCooldownException(
      message: response.message,
      availableAt: availableAt,
    );
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

  static void _validateSelection(List<int> ids, int favoriteTeamId) {
    if (ids.isEmpty || ids.length > maxFollowingTeams) {
      throw RangeError.range(
        ids.length,
        1,
        maxFollowingTeams,
        'teamIds.length',
      );
    }
    for (final id in ids) {
      if (id < 1) {
        throw RangeError.value(id, 'teamIds', 'IDs must be positive');
      }
    }
    if (ids.length != ids.toSet().length) {
      throw ArgumentError.value(ids, 'teamIds', 'IDs must not be repeated');
    }
    if (!ids.contains(favoriteTeamId)) {
      throw ArgumentError.value(
        favoriteTeamId,
        'favoriteTeamId',
        'Must be included in teamIds',
      );
    }
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
