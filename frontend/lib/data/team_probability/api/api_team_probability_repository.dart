import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_mapper.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_response.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_probability.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/probability`.
class ApiTeamProbabilityRepository implements TeamProbabilityRepository {
  ApiTeamProbabilityRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<TeamProbabilityQuery, DateTime> _savedAt = {};
  final ValueNotifier<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      _cachedSnapshots = ValueNotifier(const {});

  @override
  ValueListenable<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      get cachedSnapshots => _cachedSnapshots;

  @override
  TeamProbabilitySnapshot? cachedForTeam(int teamId, {int? seasonId}) {
    return _cachedSnapshots
        .value[TeamProbabilityQuery(teamId: teamId, seasonId: seasonId)];
  }

  @override
  Future<TeamProbabilitySnapshot> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final query = TeamProbabilityQuery(teamId: teamId, seasonId: seasonId);
    final cached = _cachedSnapshots.value[query];
    if (cached != null) {
      _refreshIfStale(query);
      return cached;
    }
    final restored = await _restore(query);
    if (restored != null) {
      _refreshIfStale(query);
      return restored;
    }
    return _fetch(query);
  }

  void _refreshIfStale(TeamProbabilityQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      unawaited(
        _fetch(query).catchError((_) => _cachedSnapshots.value[query]!),
      );
    }
  }

  Future<TeamProbabilitySnapshot?> _restore(
    TeamProbabilityQuery query,
  ) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.teamProbability(query.teamId, query.seasonId);
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final snapshot = _mapAndVerify(decoded, query);
      _publish(query, snapshot, record.savedAt);
      return snapshot;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<TeamProbabilitySnapshot> _fetch(TeamProbabilityQuery query) async {
    final teamId = query.teamId;
    final seasonId = query.seasonId;

    final uri = _api.baseUri.resolve('teams/$teamId/probability').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) {
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Probability',
      );
    }

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final snapshot = _mapAndVerify(decoded, query);
    _publish(query, snapshot, DateTime.now().toUtc());
    await _cacheStore?.write(
      LocalCacheKeys.teamProbability(teamId, seasonId),
      decoded,
    );
    return snapshot;
  }

  TeamProbabilitySnapshot _mapAndVerify(
    Map<String, dynamic> decoded,
    TeamProbabilityQuery query,
  ) {
    final teamId = query.teamId;
    final seasonId = query.seasonId;
    final apiResponse = ApiTeamProbabilityResponse.fromJson(decoded);
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

    final snapshot = teamProbabilityFromApiResponse(apiResponse);
    return snapshot;
  }

  void _publish(
    TeamProbabilityQuery query,
    TeamProbabilitySnapshot snapshot,
    DateTime savedAt,
  ) {
    final actualQuery = TeamProbabilityQuery(
      teamId: snapshot.teamId,
      seasonId: snapshot.seasonId,
    );
    _cachedSnapshots.value = Map.unmodifiable({
      ..._cachedSnapshots.value,
      query: snapshot,
      actualQuery: snapshot,
    });
    _savedAt[query] = savedAt;
    _savedAt[actualQuery] = savedAt;
  }
}
