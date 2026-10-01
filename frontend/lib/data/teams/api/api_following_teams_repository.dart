import 'package:onetouch/models/profile_change_limit_exception.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/teams/api/api_following_teams_response.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/data/local/local_cache_store.dart';

class ApiFollowingTeamsRepository implements FollowingTeamsRepository {
  ApiFollowingTeamsRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  static const int maxFollowingTeams = 5;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final ValueNotifier<List<Team>> _cachedTeams = ValueNotifier(const []);

  @override
  ValueListenable<List<Team>> get cachedTeams => _cachedTeams;

  @override
  Future<List<Team>> load() => _fetchAndCache();

  Future<List<Team>?> restoreCached() async {
    final record = await _cacheStore?.read(
      LocalCacheKeys.followingTeams,
      scope: LocalCacheScopes.authenticatedUser,
    );
    if (record == null) return null;
    try {
      final teams = _parseTeams(record.payload);
      _cachedTeams.value = teams;
      return teams;
    } on Object {
      await _cacheStore?.delete(
        LocalCacheKeys.followingTeams,
        scope: LocalCacheScopes.authenticatedUser,
      );
      return null;
    }
  }

  void clearMemory() => _cachedTeams.value = const [];

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) async {
    final ids = List<int>.unmodifiable(teamIds);
    _validateSelection(ids, favoriteTeamId);

    final uri = _api.baseUri.resolve('users/me/following/teams');
    final response = await _api.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'teamIds': ids,
        'favoriteTeamId': favoriteTeamId,
      }),
    );
    if (response.statusCode == 409) {
      throw _changeLimitException(
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: 409),
      );
    }

    final update = ApiFollowingTeamsUpdateResponse.fromJson(
      _api.decodeJson<Map<String, dynamic>>(response),
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
    final uri = _api.baseUri.resolve('users/me/following/teams');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<List<dynamic>>(response);
    final teams = _parseTeams(decoded);
    await _cacheStore?.write(
      LocalCacheKeys.followingTeams,
      decoded,
      scope: LocalCacheScopes.authenticatedUser,
    );
    _cachedTeams.value = teams;
    return teams;
  }

  List<Team> _parseTeams(Object decoded) {
    if (decoded is! List) {
      throw const FormatException(
        'Expected following teams to be a JSON list.',
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

    return teams;
  }

  static ProfileChangeLimitException _changeLimitException(
          Map<String, dynamic> body) =>
      ProfileChangeLimitException.fromJson(
          body['detail'] as Map<String, dynamic>);

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
}
