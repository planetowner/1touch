import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_mapper.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_response.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/team_best_eleven.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/best-eleven`.
class ApiBestElevenRepository implements BestElevenRepository {
  ApiBestElevenRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<BestElevenQuery, DateTime> _savedAt = {};
  final ValueNotifier<Map<BestElevenQuery, TeamBestEleven>> _cachedLineups =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<BestElevenQuery, TeamBestEleven>> get cachedLineups =>
      _cachedLineups;

  @override
  TeamBestEleven? cachedForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) {
    return _cachedLineups.value[BestElevenQuery(
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
    )];
  }

  @override
  Future<TeamBestEleven?> loadForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) async {
    final query = BestElevenQuery(
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
    );
    final cached = _cachedLineups.value[query];
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

  void _refreshIfStale(BestElevenQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      unawaited(
        _fetch(query).catchError((_) => _cachedLineups.value[query]),
      );
    }
  }

  Future<TeamBestEleven?> _restore(BestElevenQuery query) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.bestEleven(
      query.teamId,
      query.seasonId,
      query.formation,
    );
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final lineup = _mapAndVerify(decoded, query);
      _publish(query, lineup, record.savedAt);
      return lineup;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<TeamBestEleven?> _fetch(BestElevenQuery query) async {
    final teamId = query.teamId;
    final seasonId = query.seasonId;

    final uri = _api.baseUri.resolve('teams/$teamId/best-eleven').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
        if (query.formation != null) 'formation': query.formation!,
      },
    );
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) return null;

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final lineup = _mapAndVerify(decoded, query);
    _publish(query, lineup, DateTime.now().toUtc());
    await _cacheStore?.write(
      LocalCacheKeys.bestEleven(teamId, seasonId, query.formation),
      decoded,
    );
    return lineup;
  }

  TeamBestEleven _mapAndVerify(
    Map<String, dynamic> decoded,
    BestElevenQuery query,
  ) {
    final teamId = query.teamId;
    final seasonId = query.seasonId;
    final apiResponse = ApiBestElevenResponse.fromJson(decoded);
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
    if (query.formation != null && apiResponse.formation != query.formation) {
      throw FormatException(
        'Expected formation ${query.formation} but received '
        '${apiResponse.formation}.',
      );
    }

    final lineup = teamBestElevenFromApiResponse(apiResponse);
    return lineup;
  }

  void _publish(
    BestElevenQuery query,
    TeamBestEleven lineup,
    DateTime savedAt,
  ) {
    _cachedLineups.value = Map.unmodifiable({
      ..._cachedLineups.value,
      query: lineup,
    });
    _savedAt[query] = savedAt;
  }
}
