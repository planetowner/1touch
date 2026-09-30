import 'dart:async';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_options_mapper.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_options_response.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_mapper.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_response.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

/// HTTP implementation of the verified team-attributes query.
///
/// The deployed endpoint returns one season per request. Omitting `season_id`
/// selects the current season; supplying it selects that historical season.
class ApiTeamAttributeRepository implements TeamAttributeRepository {
  ApiTeamAttributeRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<int, List<TeamAttributeSeasonOption>> _options = {};
  final Map<int, DateTime> _optionsSavedAt = {};
  final Map<(int, int?), List<TeamAttributeScores>> _scores = {};
  final Map<(int, int?), DateTime> _scoresSavedAt = {};

  @override
  Future<List<TeamAttributeSeasonOption>> loadOptionsForTeam(int teamId) async {
    final memory = _options[teamId];
    if (memory != null) {
      _refreshOptionsIfStale(teamId);
      return memory;
    }
    final restored = await _restoreOptions(teamId);
    if (restored != null) {
      _refreshOptionsIfStale(teamId);
      return restored;
    }
    return _fetchOptions(teamId);
  }

  void _refreshOptionsIfStale(int teamId) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _optionsSavedAt[teamId],
    )) {
      unawaited(_fetchOptions(teamId).catchError((_) => _options[teamId]!));
    }
  }

  Future<List<TeamAttributeSeasonOption>?> _restoreOptions(int teamId) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.teamAttributeOptions(teamId);
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final result = _mapOptions(decoded, teamId);
      _options[teamId] = result;
      _optionsSavedAt[teamId] = record.savedAt;
      return result;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<List<TeamAttributeSeasonOption>> _fetchOptions(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId/attributes/options');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final result = _mapOptions(decoded, teamId);
    _options[teamId] = result;
    _optionsSavedAt[teamId] = DateTime.now().toUtc();
    await _cacheStore?.write(
      LocalCacheKeys.teamAttributeOptions(teamId),
      decoded,
    );
    return result;
  }

  List<TeamAttributeSeasonOption> _mapOptions(
    Map<String, dynamic> decoded,
    int teamId,
  ) {
    final apiResponse = ApiTeamAttributeOptionsResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }
    return teamAttributeOptionsFromApiResponse(apiResponse);
  }

  @override
  Future<List<TeamAttributeScores>> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final query = (teamId, seasonId);
    final memory = _scores[query];
    if (memory != null) {
      _refreshScoresIfStale(query);
      return memory;
    }
    final restored = await _restoreScores(query);
    if (restored != null) {
      _refreshScoresIfStale(query);
      return restored;
    }
    return _fetchScores(query);
  }

  void _refreshScoresIfStale((int, int?) query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _scoresSavedAt[query],
    )) {
      unawaited(_fetchScores(query).catchError((_) => _scores[query]!));
    }
  }

  Future<List<TeamAttributeScores>?> _restoreScores(
    (int, int?) query,
  ) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.teamAttributes(query.$1, query.$2);
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final result = _mapScores(decoded, query);
      _scores[query] = result;
      _scoresSavedAt[query] = record.savedAt;
      return result;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<List<TeamAttributeScores>> _fetchScores((int, int?) query) async {
    final teamId = query.$1;
    final seasonId = query.$2;
    final uri = _api.baseUri.resolve('teams/$teamId/attributes').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final result = _mapScores(decoded, query);
    _scores[query] = result;
    _scoresSavedAt[query] = DateTime.now().toUtc();
    await _cacheStore?.write(
      LocalCacheKeys.teamAttributes(teamId, seasonId),
      decoded,
    );
    return result;
  }

  List<TeamAttributeScores> _mapScores(
    Map<String, dynamic> decoded,
    (int, int?) query,
  ) {
    final teamId = query.$1;
    final seasonId = query.$2;
    final apiResponse = ApiTeamAttributeResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }
    if (seasonId != null && apiResponse.seasonId != seasonId) {
      throw FormatException(
        'Expected season_id $seasonId but received ${apiResponse.seasonId}.',
      );
    }

    return List.unmodifiable([
      teamAttributeScoresFromApiResponse(apiResponse),
    ]);
  }
}
