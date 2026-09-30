import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_mapper.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/team_contract_roster.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/contracts`.
class ApiTeamContractRepository implements TeamContractRepository {
  ApiTeamContractRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<TeamContractQuery, DateTime> _savedAt = {};
  final Map<TeamContractQuery, Future<TeamContractRoster>> _inFlight = {};
  final ValueNotifier<Map<TeamContractQuery, TeamContractRoster>>
      _cachedRosters = ValueNotifier(const {});

  @override
  ValueListenable<Map<TeamContractQuery, TeamContractRoster>>
      get cachedRosters => _cachedRosters;

  @override
  TeamContractRoster? cachedForTeam(
    int teamId, {
    int? seasonId,
  }) {
    return _cachedRosters.value[TeamContractQuery(
      teamId: teamId,
      seasonId: seasonId,
    )];
  }

  @override
  Future<TeamContractRoster> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final query = TeamContractQuery(teamId: teamId, seasonId: seasonId);
    final cached = _cachedRosters.value[query];
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

  void _refreshIfStale(TeamContractQuery query) {
    if (!AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      return;
    }
    unawaited(_fetch(query).catchError((_) => _cachedRosters.value[query]!));
  }

  Future<TeamContractRoster?> _restore(TeamContractQuery query) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.teamContracts(query.teamId, query.seasonId);
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final roster = _mapAndVerify(decoded, query);
      _publish(query, roster, savedAt: record.savedAt);
      return roster;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<TeamContractRoster> _fetch(TeamContractQuery query) {
    return _inFlight.putIfAbsent(query, () async {
      try {
        return await _fetchUnshared(query);
      } finally {
        _inFlight.remove(query);
      }
    });
  }

  Future<TeamContractRoster> _fetchUnshared(TeamContractQuery query) async {
    final teamId = query.teamId;
    final seasonId = query.seasonId;

    // The backend's default ordering is ascending by contract end date, with
    // missing end dates last. Screen-specific reordering remains a UI concern.
    final uri = _api.baseUri.resolve('teams/$teamId/contracts').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final roster = _mapAndVerify(decoded, query);
    final savedAt = DateTime.now().toUtc();
    _publish(query, roster, savedAt: savedAt);
    await _cacheStore?.write(
      LocalCacheKeys.teamContracts(teamId, seasonId),
      decoded,
    );
    return roster;
  }

  TeamContractRoster _mapAndVerify(
    Map<String, dynamic> decoded,
    TeamContractQuery query,
  ) {
    final apiResponse = ApiTeamContractsResponse.fromJson(decoded);
    final teamId = query.teamId;
    final seasonId = query.seasonId;
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

    final roster = teamContractRosterFromApiResponse(apiResponse);
    return roster;
  }

  void _publish(
    TeamContractQuery query,
    TeamContractRoster roster, {
    required DateTime savedAt,
  }) {
    _cachedRosters.value = Map.unmodifiable({
      ..._cachedRosters.value,
      query: roster,
    });
    _savedAt[query] = savedAt;
  }
}
